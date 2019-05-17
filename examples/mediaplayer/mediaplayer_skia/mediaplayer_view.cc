// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/examples/mediaplayer/mediaplayer_skia/mediaplayer_view.h"

#include <fcntl.h>
#include <hid/usages.h>

#include <iomanip>

#include "lib/component/cpp/connect.h"
#include "lib/fidl/cpp/clone.h"
#include "lib/fidl/cpp/optional.h"
#include "lib/fsl/io/fd.h"
#include "lib/media/timeline/type_converters.h"
#include "lib/ui/scenic/cpp/view_token_pair.h"
#include "src/lib/fxl/logging.h"
#include "src/lib/fxl/time/time_delta.h"
#include "src/lib/url/gurl.h"
#include "third_party/skia/include/core/SkColor.h"
#include "third_party/skia/include/core/SkPath.h"

namespace examples {

namespace {

constexpr int32_t kDefaultWidth = 640;
constexpr int32_t kDefaultHeight = 100;

constexpr float kBackgroundElevation = 0.f;
constexpr float kVideoElevation = -1.f;
constexpr float kControlsElevation = -1.f;

constexpr float kMargin = 4.0f;
constexpr float kControlsHeight = 36.0f;
constexpr float kSymbolWidth = 24.0f;
constexpr float kSymbolHeight = 24.0f;
constexpr float kSymbolPadding = 12.0f;

constexpr SkColor kProgressBarForegroundColor = 0xff673ab7;  // Deep Purple 500
constexpr SkColor kProgressBarBackgroundColor = 0xffb39ddb;  // Deep Purple 200
constexpr SkColor kProgressBarSymbolColor = 0xffffffff;

// Determines whether the rectangle contains the point x,y.
bool Contains(const fuchsia::math::RectF& rect, float x, float y) {
  return rect.x <= x && rect.y <= y && rect.x + rect.width >= x &&
         rect.y + rect.height >= y;
}

}  // namespace

MediaPlayerView::MediaPlayerView(scenic::ViewContext view_context,
                                 async::Loop* loop,
                                 const MediaPlayerParams& params)
    : BaseView(std::move(view_context), "Media Player"),
      loop_(loop),
      background_node_(session()),
      controls_widget_(session()) {
  FXL_DCHECK(loop);
  FXL_DCHECK(params.is_valid());

  scenic::Material background_material(session());
  background_material.SetColor(0x1a, 0x23, 0x7e, 0xff);  // Indigo 900
  background_node_.SetMaterial(background_material);
  root_node().AddChild(background_node_);
  root_node().AddChild(controls_widget_);

  // We start with a non-zero size so we get a progress bar regardless of
  // whether we get video.
  video_size_.width = 0;
  video_size_.height = 0;
  pixel_aspect_ratio_.width = 1;
  pixel_aspect_ratio_.height = 1;

  player_ =
      startup_context()
          ->ConnectToEnvironmentService<fuchsia::media::playback::Player>();
  player_.events().OnStatusChanged =
      [this](fuchsia::media::playback::PlayerStatus status) {
        HandleStatusChanged(status);
      };

  auto [view_token, view_holder_token] = scenic::ViewTokenPair::New();

  player_->CreateView(std::move(view_token));

  video_host_view_holder_ = std::make_unique<scenic::ViewHolder>(
      session(), std::move(view_holder_token), "Player");
  video_host_node_ = std::make_unique<scenic::EntityNode>(session());
  video_host_node_->Attach(*video_host_view_holder_);

  if (!params.url().empty()) {
    url::GURL url = url::GURL(params.url());

    if (url.SchemeIsFile()) {
      player_->SetFileSource(fsl::CloneChannelFromFileDescriptor(
          fxl::UniqueFD(open(url.path().c_str(), O_RDONLY)).get()));
    } else {
      player_->SetHttpSource(params.url(), nullptr);
    }

    // Get the first frames queued up so we can show something.
    player_->Pause();
  }

  // These are for calculating frame rate.
  frame_time_ = zx::clock::get_monotonic().get();
  prev_frame_time_ = frame_time_;
}

void MediaPlayerView::OnInputEvent(fuchsia::ui::input::InputEvent event) {
  if (event.is_pointer()) {
    const auto& pointer = event.pointer();
    if (pointer.phase == fuchsia::ui::input::PointerEventPhase::DOWN) {
      if (!Contains(progress_bar_rect_, pointer.x, pointer.y)) {
        // User poked outside the progress bar.
        TogglePlayPause();
      } else if (duration_ns_ != 0) {
        // User poked the progress bar and we have duration...seek.
        player_->Seek((pointer.x - progress_bar_rect_.x) * duration_ns_ /
                      progress_bar_rect_.width);
        if (state_ != State::kPlaying) {
          player_->Play();
        }
      }
    }
  } else if (event.is_keyboard()) {
    auto& keyboard = event.keyboard();
    if (keyboard.phase == fuchsia::ui::input::KeyboardEventPhase::PRESSED) {
      switch (keyboard.hid_usage) {
        case HID_USAGE_KEY_SPACE:
          TogglePlayPause();
          break;
        case HID_USAGE_KEY_Q:
          loop_->Quit();
          break;
        default:
          break;
      }
    }
  }
}

void MediaPlayerView::OnScenicEvent(fuchsia::ui::scenic::Event event) {
  switch (event.Which()) {
    case fuchsia::ui::scenic::Event::Tag::kGfx:
      switch (event.gfx().Which()) {
        case fuchsia::ui::gfx::Event::Tag::kViewConnected: {
          FXL_DCHECK(video_host_view_holder_ &&
                     event.gfx().view_connected().view_holder_id ==
                         video_host_view_holder_->id());

          root_node().AddChild(*video_host_node_);
          Layout();
          break;
        }
        case fuchsia::ui::gfx::Event::Tag::kViewDisconnected: {
          FXL_DCHECK(video_host_view_holder_ &&
                     event.gfx().view_disconnected().view_holder_id ==
                         video_host_view_holder_->id());
          FXL_LOG(ERROR) << "Video view died unexpectedly";

          video_host_node_->Detach();
          video_host_node_.reset();
          video_host_view_holder_.reset();
          Layout();
          break;
        }
        default:
          FXL_LOG(WARNING)
              << "MediaPlayerView::OnScenicEvent: Got an unhandled GFX "
                 "event.";
          break;
      }
      break;
    default:
      FXL_DCHECK(false)
          << "MediaPlayerView::OnScenicEvent: Got an unhandled Scenic "
             "event.";
      break;
  }
}

void MediaPlayerView::OnPropertiesChanged(
    fuchsia::ui::gfx::ViewProperties old_properties) {
  Layout();
}

void MediaPlayerView::Layout() {
  if (!has_logical_size())
    return;

  // Make the background fill the space.
  scenic::Rectangle background_shape(session(), logical_size().x,
                                     logical_size().y);
  background_node_.SetShape(background_shape);
  background_node_.SetTranslation(
      logical_size().x * .5f, logical_size().y * .5f, -kBackgroundElevation);

  // Compute maximum size of video content after reserving space
  // for decorations.
  fuchsia::math::SizeF max_content_size;
  max_content_size.width = logical_size().x - kMargin * 2;
  max_content_size.height = logical_size().y - kControlsHeight - kMargin * 3;

  // Shrink video to fit if needed.
  uint32_t video_width =
      (video_size_.width == 0 ? kDefaultWidth : video_size_.width) *
      pixel_aspect_ratio_.width;
  uint32_t video_height =
      (video_size_.height == 0 ? kDefaultHeight : video_size_.height) *
      pixel_aspect_ratio_.height;

  if (max_content_size.width * video_height <
      max_content_size.height * video_width) {
    content_rect_.width = max_content_size.width;
    content_rect_.height = video_height * max_content_size.width / video_width;
  } else {
    content_rect_.width = video_width * max_content_size.height / video_height;
    content_rect_.height = max_content_size.height;
  }

  // Add back in the decorations and center within view.
  fuchsia::math::RectF ui_rect;
  ui_rect.width = content_rect_.width;
  ui_rect.height = content_rect_.height + kControlsHeight + kMargin;
  ui_rect.x = (logical_size().x - ui_rect.width) / 2;
  ui_rect.y = (logical_size().y - ui_rect.height) / 2;

  // Position the video.
  content_rect_.x = ui_rect.x;
  content_rect_.y = ui_rect.y;

  // Position the controls.
  controls_rect_.x = content_rect_.x;
  controls_rect_.y = content_rect_.y + content_rect_.height + kMargin;
  controls_rect_.width = content_rect_.width;
  controls_rect_.height = kControlsHeight;

  // Position the progress bar (for input).
  progress_bar_rect_.x = controls_rect_.x + kSymbolWidth + kSymbolPadding * 2;
  progress_bar_rect_.y = controls_rect_.y;
  progress_bar_rect_.width =
      controls_rect_.width - (kSymbolWidth + kSymbolPadding * 2);
  progress_bar_rect_.height = controls_rect_.height;

  // Ask the view to fill the space.
  if (video_host_view_holder_) {
    fuchsia::ui::gfx::ViewProperties view_properties{
        .bounding_box =
            fuchsia::ui::gfx::BoundingBox{
                .min =
                    fuchsia::ui::gfx::vec3{
                        .x = 0.f,
                        .y = 0.f,
                        .z = kVideoElevation,
                    },
                .max =
                    fuchsia::ui::gfx::vec3{
                        .x = content_rect_.width,
                        .y = content_rect_.height,
                        .z = kVideoElevation,
                    },
            },
        .inset_from_min =
            fuchsia::ui::gfx::vec3{
                .x = 0.f,
                .y = 0.f,
                .z = kVideoElevation,
            },
        .inset_from_max =
            fuchsia::ui::gfx::vec3{
                .x = 0.f,
                .y = 0.f,
                .z = kVideoElevation,
            },
        .focus_change = false,
    };
    video_host_view_holder_->SetViewProperties(view_properties);
  }

  InvalidateScene();
}

void MediaPlayerView::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (!has_physical_size())
    return;

  prev_frame_time_ = frame_time_;
  frame_time_ = zx::clock::get_monotonic().get();

  // Log the frame rate every five seconds.
  if (state_ == State::kPlaying &&
      fxl::TimeDelta::FromNanoseconds(frame_time_).ToSeconds() / 5 !=
          fxl::TimeDelta::FromNanoseconds(prev_frame_time_).ToSeconds() / 5) {
    FXL_DLOG(INFO) << "frame rate " << frame_rate() << " fps";
  }

  // Position the video.
  if (video_host_node_) {
    video_host_node_->SetTranslation(content_rect_.x, content_rect_.y,
                                     kVideoElevation);
  }

  // Draw the progress bar.
  SkISize controls_size =
      SkISize::Make(controls_rect_.width, controls_rect_.height);
  SkCanvas* controls_canvas = controls_widget_.AcquireCanvas(
      controls_rect_.width, controls_rect_.height, metrics().scale_x,
      metrics().scale_y);
  DrawControls(controls_canvas, controls_size);
  controls_widget_.ReleaseAndSwapCanvas();
  controls_widget_.SetTranslation(
      controls_rect_.x + controls_rect_.width * .5f,
      controls_rect_.y + controls_rect_.height * .5f, kControlsElevation);

  // Animate the progress bar.
  if (state_ == State::kPlaying) {
    InvalidateScene();
  }
}

void MediaPlayerView::DrawControls(SkCanvas* canvas, const SkISize& size) {
  canvas->clear(SK_ColorBLACK);

  // Draw the progress bar itself (blue on gray).
  float progress_bar_left = kSymbolWidth + kSymbolPadding * 2;
  float progress_bar_width = size.width() - progress_bar_left;
  SkPaint paint;
  paint.setColor(kProgressBarBackgroundColor);
  canvas->drawRect(
      SkRect::MakeXYWH(progress_bar_left, 0, progress_bar_width, size.height()),
      paint);

  paint.setColor(kProgressBarForegroundColor);
  canvas->drawRect(
      SkRect::MakeXYWH(progress_bar_left, 0, progress_bar_width * progress(),
                       size.height()),
      paint);

  paint.setColor(kProgressBarSymbolColor);
  float symbol_left = kSymbolPadding;
  float symbol_top = (size.height() - kSymbolHeight) / 2.0f;
  if (state_ == State::kPlaying) {
    // Playing...draw a pause symbol.
    canvas->drawRect(SkRect::MakeXYWH(symbol_left, symbol_top,
                                      kSymbolWidth / 3.0f, kSymbolHeight),
                     paint);

    canvas->drawRect(
        SkRect::MakeXYWH(symbol_left + 2 * kSymbolWidth / 3.0f, symbol_top,
                         kSymbolWidth / 3.0f, kSymbolHeight),
        paint);
  } else {
    // Playing...draw a play symbol.
    SkPath path;
    path.moveTo(symbol_left, symbol_top);
    path.lineTo(symbol_left, symbol_top + kSymbolHeight);
    path.lineTo(symbol_left + kSymbolWidth, symbol_top + kSymbolHeight / 2.0f);
    path.lineTo(symbol_left, symbol_top);
    canvas->drawPath(path, paint);
  }
}

void MediaPlayerView::HandleStatusChanged(
    const fuchsia::media::playback::PlayerStatus& status) {
  // Process status received from the player.
  if (status.timeline_function) {
    timeline_function_ =
        fidl::To<media::TimelineFunction>(*status.timeline_function);
  }

  previous_state_ = state_;
  if (status.end_of_stream) {
    state_ = State::kEnded;
  } else if (timeline_function_.subject_delta() == 0) {
    state_ = State::kPaused;
  } else {
    state_ = State::kPlaying;
  }

  // TODO(dalesat): Display problems on the screen.
  if (status.problem) {
    if (!problem_shown_) {
      FXL_DLOG(INFO) << "PROBLEM: " << status.problem->type << ", "
                     << status.problem->details;
      problem_shown_ = true;
    }
  } else {
    problem_shown_ = false;
  }

  if (status.video_size && status.pixel_aspect_ratio &&
      (video_size_ != *status.video_size ||
       pixel_aspect_ratio_ != *status.pixel_aspect_ratio)) {
    video_size_ = *status.video_size;
    pixel_aspect_ratio_ = *status.pixel_aspect_ratio;

    FXL_LOG(INFO) << "video size " << status.video_size->width << "x"
                  << status.video_size->height << ", pixel aspect ratio "
                  << status.pixel_aspect_ratio->width << "x"
                  << status.pixel_aspect_ratio->height;

    Layout();
  }

  duration_ns_ = status.duration;

  // TODO(dalesat): Display metadata on the screen.
  if (status.metadata && !metadata_shown_) {
    FXL_DLOG(INFO) << "duration   " << std::fixed << std::setprecision(1)
                   << double(duration_ns_) / 1000000000.0 << " seconds";
    for (auto& property : status.metadata->properties) {
      FXL_DLOG(INFO) << property.label << ": " << property.value;
    }

    metadata_shown_ = true;
  }

  InvalidateScene();
}

void MediaPlayerView::TogglePlayPause() {
  switch (state_) {
    case State::kPaused:
      player_->Play();
      break;
    case State::kPlaying:
      player_->Pause();
      break;
    case State::kEnded:
      player_->Seek(0);
      player_->Play();
      break;
    default:
      break;
  }
}

float MediaPlayerView::progress() const {
  if (duration_ns_ == 0) {
    return 0.0f;
  }

  // Apply the timeline function to the current time.
  int64_t position = timeline_function_(zx::clock::get_monotonic().get());

  if (position < 0) {
    position = 0;
  }

  if (position > duration_ns_) {
    position = duration_ns_;
  }

  return position / static_cast<float>(duration_ns_);
}

}  // namespace examples

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_MEDIA_MEDIA_PLAYER_SKIA_MEDIA_PLAYER_VIEW_H_
#define TOPAZ_EXAMPLES_MEDIA_MEDIA_PLAYER_SKIA_MEDIA_PLAYER_VIEW_H_

#include <memory>
#include <queue>

#include <fuchsia/media/cpp/fidl.h>
#include <fuchsia/mediaplayer/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>

#include "examples/ui/lib/host_canvas_cycler.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fxl/macros.h"
#include "lib/media/timeline/timeline_function.h"
#include "lib/ui/view_framework/base_view.h"
#include "topaz/examples/media/media_player_skia/media_player_params.h"

namespace examples {

class MediaPlayerView : public mozart::BaseView {
 public:
  MediaPlayerView(async::Loop* loop,
                  fuchsia::ui::views_v1::ViewManagerPtr view_manager,
                  fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner>
                      view_owner_request,
                  component::StartupContext* startup_context,
                  const MediaPlayerParams& params);

  ~MediaPlayerView() override;

 private:
  enum class State { kPaused, kPlaying, kEnded };

  // |BaseView|:
  void OnPropertiesChanged(
      fuchsia::ui::views_v1::ViewProperties old_properties) override;
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  void OnChildAttached(
      uint32_t child_key,
      fuchsia::ui::views_v1::ViewInfo child_view_info) override;
  void OnChildUnavailable(uint32_t child_key) override;
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  // Perform a layout of the UI elements.
  void Layout();

  // Draws the progress bar, etc, into the provided canvas.
  void DrawControls(SkCanvas* canvas, const SkISize& size);

  // Handles a status update from the player. When called with the default
  // argument values, initiates status updates.
  void HandleStatusChanged(
      const fuchsia::mediaplayer::MediaPlayerStatus& status);

  // Toggles between play and pause.
  void TogglePlayPause();

  // Returns progress in the range 0.0 to 1.0.
  float progress() const;

  // Returns the current frame rate in frames per second.
  float frame_rate() const {
    if (frame_time_ == prev_frame_time_) {
      return 0.0f;
    }

    return float(1000000000.0 / double(frame_time_ - prev_frame_time_));
  }

  async::Loop* const loop_;

  scenic::ShapeNode background_node_;
  scenic::skia::HostCanvasCycler controls_widget_;
  std::unique_ptr<scenic::EntityNode> video_host_node_;

  fuchsia::mediaplayer::MediaPlayerPtr media_player_;
  fuchsia::math::Size video_size_;
  fuchsia::math::Size pixel_aspect_ratio_;
  State previous_state_ = State::kPaused;
  State state_ = State::kPaused;
  media::TimelineFunction timeline_function_;
  fuchsia::mediaplayer::MediaMetadataPtr metadata_;
  fuchsia::math::RectF content_rect_;
  fuchsia::math::RectF controls_rect_;
  fuchsia::math::RectF progress_bar_rect_;
  bool metadata_shown_ = false;
  bool problem_shown_ = false;

  int64_t frame_time_;
  int64_t prev_frame_time_;

  FXL_DISALLOW_COPY_AND_ASSIGN(MediaPlayerView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_MEDIA_MEDIA_PLAYER_SKIA_MEDIA_PLAYER_VIEW_H_

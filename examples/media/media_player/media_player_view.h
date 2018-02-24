// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <memory>
#include <queue>

#include "examples/ui/lib/host_canvas_cycler.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fxl/macros.h"
#include "lib/media/fidl/media_player.fidl.h"
#include "lib/media/fidl/net_media_player.fidl.h"
#include "lib/media/fidl/video_renderer.fidl.h"
#include "lib/media/timeline/timeline_function.h"
#include "lib/ui/view_framework/base_view.h"
#include "topaz/examples/media/media_player/media_player_params.h"

namespace examples {

class MediaPlayerView : public mozart::BaseView {
 public:
  MediaPlayerView(mozart::ViewManagerPtr view_manager,
                  f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
                  app::ApplicationContext* application_context,
                  const MediaPlayerParams& params);

  ~MediaPlayerView() override;

 private:
  enum class State { kPaused, kPlaying, kEnded };

  // |BaseView|:
  void OnPropertiesChanged(mozart::ViewPropertiesPtr old_properties) override;
  void OnSceneInvalidated(
      ui_mozart::PresentationInfoPtr presentation_info) override;
  void OnChildAttached(uint32_t child_key,
                       mozart::ViewInfoPtr child_view_info) override;
  void OnChildUnavailable(uint32_t child_key) override;
  bool OnInputEvent(mozart::InputEventPtr event) override;

  // Perform a layout of the UI elements.
  void Layout();

  // Draws the progress bar, etc, into the provided canvas.
  void DrawControls(SkCanvas* canvas, const SkISize& size);

  // Handles a status update from the player. When called with the default
  // argument values, initiates status updates.
  void HandlePlayerStatusUpdates(
      uint64_t version = media::MediaPlayer::kInitialStatus,
      media::MediaPlayerStatusPtr status = nullptr);

  // Handles a status update from the vidoe renderer. When called with the
  // default argument values, initiates status updates.
  void HandleVideoRendererStatusUpdates(
      uint64_t version = media::VideoRenderer::kInitialStatus,
      media::VideoRendererStatusPtr status = nullptr);

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

  scenic_lib::ShapeNode background_node_;
  scenic_lib::skia::HostCanvasCycler controls_widget_;
  std::unique_ptr<scenic_lib::EntityNode> video_host_node_;

  media::NetMediaPlayerPtr net_media_player_;
  media::VideoRendererPtr video_renderer_;
  mozart::ViewPropertiesPtr video_view_properties_;
  mozart::Size video_size_;
  mozart::Size pixel_aspect_ratio_;
  State previous_state_ = State::kPaused;
  State state_ = State::kPaused;
  media::TimelineFunction timeline_function_;
  media::MediaMetadataPtr metadata_;
  mozart::RectF content_rect_;
  mozart::RectF controls_rect_;
  mozart::RectF progress_bar_rect_;
  bool metadata_shown_ = false;
  bool problem_shown_ = false;

  int64_t frame_time_;
  int64_t prev_frame_time_;

  FXL_DISALLOW_COPY_AND_ASSIGN(MediaPlayerView);
};

}  // namespace examples

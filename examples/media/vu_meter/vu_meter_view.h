// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_EXAMPLES_MEDIA_VU_METER_VU_METER_VIEW_H_
#define TOPAZ_EXAMPLES_MEDIA_VU_METER_VU_METER_VIEW_H_

#include <memory>
#include <queue>

#include <fuchsia/media/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>
#include <lib/fzl/vmo-mapper.h>

#include "examples/ui/lib/skia_view.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fxl/macros.h"

namespace examples {

class VuMeterView : public scenic::SkiaView {
 public:
  VuMeterView(scenic::ViewContext view_context, async::Loop* loop);
  ~VuMeterView() override = default;

 private:
  static constexpr float kVuFullWidth = 35000.0f;
  static constexpr float kFastDecay = 0.0001f;
  static constexpr float kSlowDecay = 0.00003f;

  class PeakFilter {
   public:
    PeakFilter(float decay) : multiplier_(1.0f - decay) {}

    float Process(float in) {
      if (current_ < in) {
        current_ = in;
      } else {
        current_ *= multiplier_;
      }
      return current_;
    }

    float current() { return current_; }

   private:
    float multiplier_;
    float current_ = 0;
  };

  // |scenic::V1BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  // Draws the UI.
  void DrawContent(SkCanvas* canvas);

  // Send a capture request to our capturer.
  void SendCaptureRequest();

  // Toggles between start and stop.
  void ToggleStartStop() {
    started_ = !started_;
    SendCaptureRequest();
  }

  // Shutdown the app
  void Shutdown();

  void OnDefaultFormatFetched(fuchsia::media::StreamType default_type);
  void OnPacketCaptured(fuchsia::media::StreamPacket packet);

  async::Loop* const loop_;
  fuchsia::media::AudioCapturerPtr audio_capturer_;
  fzl::VmoMapper payload_buffer_;
  bool started_ = false;
  bool request_in_flight_ = false;

  PeakFilter fast_left_;
  PeakFilter fast_right_;
  PeakFilter slow_left_;
  PeakFilter slow_right_;

  FXL_DISALLOW_COPY_AND_ASSIGN(VuMeterView);
};

}  // namespace examples

#endif  // TOPAZ_EXAMPLES_MEDIA_VU_METER_VU_METER_VIEW_H_

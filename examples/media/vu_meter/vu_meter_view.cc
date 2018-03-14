// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/examples/media/vu_meter/vu_meter_view.h"

#include <hid/usages.h>

#include <iomanip>

#include "topaz/examples/media/vu_meter/vu_meter_params.h"
#include "lib/app/cpp/connect.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/logging.h"
#include "lib/media/audio/types.h"
#include "lib/media/fidl/audio_server.fidl.h"
#include "third_party/skia/include/core/SkColor.h"
#include "third_party/skia/include/core/SkPath.h"

constexpr zx_duration_t kCaptureDuration = ZX_MSEC(20);
constexpr uint64_t kBytesPerFrame = 4;

namespace examples {

VuMeterView::VuMeterView(
    mozart::ViewManagerPtr view_manager,
    f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
    app::ApplicationContext* application_context,
    const VuMeterParams& params)
    : mozart::SkiaView(std::move(view_manager),
                       std::move(view_owner_request),
                       "VU Meter"),
      fast_left_(kFastDecay),
      fast_right_(kFastDecay),
      slow_left_(kSlowDecay),
      slow_right_(kSlowDecay) {
  FXL_DCHECK(params.is_valid());

  auto audio_server =
      application_context->ConnectToEnvironmentService<media::AudioServer>();
  audio_server->CreateCapturer(capturer_.NewRequest(), false);

  capturer_.set_error_handler([this]() {
    FXL_LOG(ERROR) << "Connection error occurred. Quitting.";
    Shutdown();
  });

  capturer_->GetMediaType([this](media::MediaTypePtr type) {
    OnDefaultFormatFetched(std::move(type));
  });
}

VuMeterView::~VuMeterView() {}

bool VuMeterView::OnInputEvent(mozart::InputEventPtr event) {
  FXL_DCHECK(event);
  bool handled = false;
  if (event->is_pointer()) {
    auto& pointer = event->get_pointer();
    if (pointer->phase == mozart::PointerEvent::Phase::DOWN) {
      ToggleStartStop();
      handled = true;
    }
  } else if (event->is_keyboard()) {
    auto& keyboard = event->get_keyboard();
    if (keyboard->phase == mozart::KeyboardEvent::Phase::PRESSED) {
      switch (keyboard->hid_usage) {
        case HID_USAGE_KEY_SPACE:
          ToggleStartStop();
          handled = true;
          break;
        case HID_USAGE_KEY_Q:
          Shutdown();
          handled = true;
          break;
        default:
          break;
      }
    }
  }
  return handled;
}

void VuMeterView::OnSceneInvalidated(
    ui::PresentationInfoPtr presentation_info) {
  SkCanvas* canvas = AcquireCanvas();
  if (canvas) {
    DrawContent(canvas);
    ReleaseAndSwapCanvas();
  }
}

void VuMeterView::DrawContent(SkCanvas* canvas) {
  canvas->clear(SK_ColorBLACK);

  SkPaint paint;
  paint.setFlags(SkPaint::kAntiAlias_Flag);

  paint.setColor(SK_ColorCYAN);
  canvas->drawCircle(
      logical_size().width / 3.0f, logical_size().height / 2,
      (fast_left_.current() * logical_size().width / 2) / kVuFullWidth, paint);
  canvas->drawCircle(
      2.0f * logical_size().width / 3.0f, logical_size().height / 2,
      (fast_right_.current() * logical_size().width / 2) / kVuFullWidth, paint);

  paint.setColor(SK_ColorWHITE);
  paint.setStyle(SkPaint::kStroke_Style);
  paint.setStrokeWidth(SkIntToScalar(3));
  canvas->drawCircle(
      logical_size().width / 3.0f, logical_size().height / 2,
      (slow_left_.current() * logical_size().width / 2) / kVuFullWidth, paint);
  canvas->drawCircle(
      2.0f * logical_size().width / 3.0f, logical_size().height / 2,
      (slow_right_.current() * logical_size().width / 2) / kVuFullWidth, paint);
}

void VuMeterView::SendCaptureRequest() {
  if (!started_ || request_in_flight_) {
    return;
  }

  // clang-format off
  capturer_->CaptureAt(
      0, payload_buffer_.size() / kBytesPerFrame,
      [this](media::MediaPacketPtr packet) {
        OnPacketCaptured(std::move(packet));
      });
  // clang-format on

  request_in_flight_ = true;
}

void VuMeterView::OnDefaultFormatFetched(media::MediaTypePtr default_type) {
  // Set the media type, keep the default sample rate but make sure that we
  // normalize to stereo 16-bit LPCM.
  FXL_DCHECK(!default_type->details.is_null());
  FXL_DCHECK(default_type->details->is_audio());
  const auto& audio_details = *(default_type->details->get_audio());
  capturer_->SetMediaType(media::CreateLpcmMediaType(
        media::AudioSampleFormat::SIGNED_16, 2, audio_details.frames_per_second));

  uint64_t payload_buffer_size =
    kBytesPerFrame * ((kCaptureDuration * audio_details.frames_per_second) / ZX_SEC(1));

  constexpr zx_rights_t rights = ZX_RIGHT_TRANSFER | ZX_RIGHT_READ | ZX_RIGHT_WRITE | ZX_RIGHT_MAP;
  zx_status_t zx_res;
  zx::vmo vmo;
  zx_res = payload_buffer_.CreateAndMap(payload_buffer_size,
                                        ZX_VM_FLAG_PERM_READ,
                                        nullptr,
                                        &vmo,
                                        rights);
  if (zx_res != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create payload buffer (res " << zx_res << ")";
    Shutdown();
    return;
  }

  capturer_->SetPayloadBuffer(std::move(vmo));

  // Start capturing.
  ToggleStartStop();
}

void VuMeterView::OnPacketCaptured(media::MediaPacketPtr packet) {
  request_in_flight_ = false;
  if (!started_) {
    return;
  }

  // TODO(dalesat): Synchronize display and captured audio.
  uint32_t frame_count = static_cast<uint32_t>(payload_buffer_.size() / kBytesPerFrame);
  int16_t* samples = reinterpret_cast<int16_t*>(payload_buffer_.start());

  for (uint32_t i = 0; i < frame_count; ++i) {
      int16_t abs_sample = std::abs(samples[0]);
      fast_left_.Process(abs_sample);
      slow_left_.Process(abs_sample);

      abs_sample = std::abs(samples[1]);
      fast_right_.Process(abs_sample);
      slow_right_.Process(abs_sample);

      samples += 2;
  }

  InvalidateScene();
  SendCaptureRequest();
}

void VuMeterView::Shutdown() {
    capturer_.Unbind();
    fsl::MessageLoop::GetCurrent()->PostQuitTask();
}

}  // namespace examples

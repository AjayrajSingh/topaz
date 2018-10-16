// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/bin/ui/skottie_viewer/view.h"

#include "lib/fsl/vmo/vector.h"
#include "lib/fxl/logging.h"
#include "third_party/skia/include/core/SkColor.h"

namespace skottie {

constexpr float kSecondsPerNanosecond = .000'000'001f;

View::View(
    async::Loop* loop, component::StartupContext* startup_context,
    ::fuchsia::ui::viewsv1::ViewManagerPtr view_manager,
    fidl::InterfaceRequest<::fuchsia::ui::viewsv1token::ViewOwner>
        view_owner_request,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> outgoing_services)
    : SkiaView(std::move(view_manager), std::move(view_owner_request),
               "Skottie View"),
      player_binding_(this) {
  if (outgoing_services) {
    service_namespace_.AddService(loader_bindings_.GetHandler(this));
    service_namespace_.AddBinding(std::move(outgoing_services));
  } else {
    startup_context->outgoing().AddPublicService(
        loader_bindings_.GetHandler(this));
  }
}

void View::Load(fuchsia::mem::Buffer payload,
                fuchsia::skia::skottie::Options options,
                LoadCallback callback) {
  std::vector<uint8_t> data;
  if (!fsl::VectorFromVmo(payload, &data)) {
    FXL_LOG(ERROR) << "VectorFromVmo failed";
    return;
  }

  start_time_ = 0L;
  background_color_ = options.background_color;
  loop_ = options.loop;
  playing_ = options.autoplay;

  class Logger final : public skottie::Logger {
   public:
    // |skottie::Logger|
    void log(skottie::Logger::Level level, const char message[],
             const char json[]) override {
      error_ = error_ || level == skottie::Logger::Level::kError;
      buffer_ << message << (json ? json : "") << std::endl;
    }

    bool has_errors() { return error_; }
    std::string log() { return buffer_.str(); }

   private:
    bool error_;
    std::ostringstream buffer_;
  };

  auto logger = sk_make_sp<Logger>();
  skottie::Animation::Builder builder;
  animation_ = builder.setLogger(logger).make(
      reinterpret_cast<const char*>(data.data()), data.size());
  duration_ = animation_->duration();

  fuchsia::skia::skottie::PlayerPtr player;
  if (animation_) {
    player_binding_.Bind(player.NewRequest());
  }

  fuchsia::skia::skottie::Status status;
  status.error = logger->has_errors();
  status.message = logger->log();
  callback(std::move(status), player);
}

void View::Seek(float t) {
  position_ = t;
  start_time_ = 0L;
  InvalidateScene();
}

void View::Play() {
  playing_ = true;
  InvalidateScene();
}

void View::Pause() {
  playing_ = false;
  InvalidateScene();
}

void View::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (animation_ && playing_) {
    SkCanvas* canvas = AcquireCanvas();
    if (!canvas)
      return;

    uint64_t presentation_time = presentation_info.presentation_time;
    if (!start_time_) {
      start_time_ = presentation_time;
    }

    float d = animation_->duration();
    float t = (presentation_time - start_time_) * kSecondsPerNanosecond +
              position_ * animation_->duration();
    animation_->seek(std::fmod(t, d) / d);

    canvas->clear(background_color_);

    Draw(canvas);

    ReleaseAndSwapCanvas();

    // Animate.
    InvalidateScene();
  }
}

void View::Draw(SkCanvas* canvas) {
  FXL_DCHECK(animation_);

  const auto rect = SkRect::MakeSize(
      SkSize::Make(logical_size().width, logical_size().height));

  SkAutoCanvasRestore acr(canvas, true);
  animation_->render(canvas, &rect);
}

}  // namespace skottie

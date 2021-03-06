// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_BIN_UI_SKOTTIE_VIEWER_VIEW_H_
#define TOPAZ_BIN_UI_SKOTTIE_VIEWER_VIEW_H_

#include <fuchsia/images/cpp/fidl.h>
#include <fuchsia/mem/cpp/fidl.h>
#include <fuchsia/skia/skottie/cpp/fidl.h>
#include <lib/fidl/cpp/binding_set.h>
#include <lib/sys/cpp/component_context.h>

#include "examples/ui/lib/skia_view.h"
#include "src/lib/fxl/macros.h"
//#if defined(SK_ENABLE_SKOTTIE)
#include "third_party/skia/modules/skottie/include/Skottie.h"
//#endif
namespace skottie {

// A view that plays Skottie animations.
class View final : public scenic::SkiaView,
                   public fuchsia::skia::skottie::Loader,
                   public fuchsia::skia::skottie::Player {
 public:
  View(scenic::ViewContext view_context);
  ~View() override = default;

  // |scenic::BaseView|
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

  // |fuchsia::skia::skottie::Loader|
  virtual void Load(fuchsia::mem::Buffer payload,
                    fuchsia::skia::skottie::Options options,
                    LoadCallback callback) override;

  // |fuchsia::skia::skottie::Player|
  virtual void Seek(float t) override;
  virtual void Play() override;
  virtual void Pause() override;

 private:
  fidl::BindingSet<fuchsia::skia::skottie::Loader> loader_bindings_;
  fidl::Binding<fuchsia::skia::skottie::Player> player_binding_;
  fuchsia::skia::skottie::PlayerPtr player_;
  component::ServiceNamespace service_namespace_;

  // Render the animation to the canvas.
  void Draw(SkCanvas* canvas);

  uint64_t start_time_ = 0u;
  float position_ = 0.f;
  float duration_ = 0.f;
  SkColor background_color_ = SK_ColorBLACK;
  bool playing_ = false;
  bool loop_ = true;

  sk_sp<skottie::Animation> animation_;

  FXL_DISALLOW_COPY_AND_ASSIGN(View);
};

}  // namespace skottie

#endif  // TOPAZ_BIN_UI_SKOTTIE_VIEWER_VIEW_H_

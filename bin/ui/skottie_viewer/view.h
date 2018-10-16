// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GARNET_EXAMPLES_UI_SKOTTIE_VIEWER_VIEW_H_
#define GARNET_EXAMPLES_UI_SKOTTIE_VIEWER_VIEW_H_

#include <lib/async-loop/cpp/loop.h>

#include <fuchsia/skia/skottie/cpp/fidl.h>

#include "examples/ui/lib/skia_view.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fxl/macros.h"
#include "lib/ui/view_framework/base_view.h"
//#if defined(SK_ENABLE_SKOTTIE)
#include "third_party/skia/modules/skottie/include/Skottie.h"
//#endif
namespace skottie {

// A view that plays Skottie animations.
class View final : public mozart::SkiaView,
                   public fuchsia::skia::skottie::Loader,
                   public fuchsia::skia::skottie::Player {
 public:
  View(async::Loop* loop, component::StartupContext* startup_context,
       ::fuchsia::ui::viewsv1::ViewManagerPtr view_manager,
       fidl::InterfaceRequest<::fuchsia::ui::viewsv1token::ViewOwner>
           view_owner_request,
       fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> outgoing_services);

  ~View() override = default;

  // |fuchsia::skia::skottie::Loader|.
  virtual void Load(fuchsia::mem::Buffer payload,
                    fuchsia::skia::skottie::Options options,
                    LoadCallback callback) override;

  // |fuchsia::skia::skottie::Player|.
  virtual void Seek(float t) override;
  virtual void Play() override;
  virtual void Pause() override;

  // |BaseView|:
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

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

#endif  // GARNET_EXAMPLES_UI_SKOTTIE_VIEWER_VIEW_H_

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/skia_font_loader.h"
#include "lib/ui/view_framework/view_provider_service.h"
#include "topaz/app/term/term_params.h"
#include "topaz/app/term/view_controller.h"

namespace term {

class App : public fuchsia::ui::views_v1::ViewProvider {
 public:
  explicit App(TermParams params);
  ~App();

  // |mozart::ViewProviderService|
  void CreateView(fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner>
                      view_owner_request,
                  fidl::InterfaceRequest<fuchsia::sys::ServiceProvider>
                      view_services) override;

  void DestroyController(ViewController* controller);

 private:
  App(const App&) = delete;
  App& operator=(const App&) = delete;

  TermParams params_;
  std::unique_ptr<component::StartupContext> context_;
  fidl::BindingSet<fuchsia::ui::views_v1::ViewProvider> bindings_;
  std::vector<std::unique_ptr<ViewController>> controllers_;
};

}  // namespace term

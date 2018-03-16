// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/skia_font_loader.h"
#include "lib/ui/view_framework/view_provider_service.h"
#include "topaz/app/term/term_params.h"
#include "topaz/app/term/view_controller.h"

namespace term {

class App : public mozart::ViewProvider {
 public:
  explicit App(TermParams params);
  ~App();

  // |mozart::ViewProvider|
  void CreateView(f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
                  f1dl::InterfaceRequest<component::ServiceProvider>
                      view_services) override;

  void DestroyController(ViewController* controller);

 private:
  App(const App&) = delete;
  App& operator=(const App&) = delete;

  TermParams params_;
  std::unique_ptr<component::ApplicationContext> context_;
  f1dl::BindingSet<mozart::ViewProvider> bindings_;
  std::vector<std::unique_ptr<ViewController>> controllers_;
};

}  // namespace term

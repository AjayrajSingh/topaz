// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <lib/zx/eventpair.h>

#include "examples/ui/lib/skia_font_loader.h"
#include "topaz/app/term/term_params.h"
#include "topaz/app/term/view_controller.h"

namespace term {

class App : public fuchsia::ui::app::ViewProvider {
 public:
  explicit App(TermParams params);
  ~App() = default;

  // |fuchsia::ui::app::ViewProvider|
  void CreateView(
      zx::eventpair view_token,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services)
      override;

  void DestroyController(ViewController* controller);

 private:
  App(const App&) = delete;
  App& operator=(const App&) = delete;

  TermParams params_;
  std::unique_ptr<component::StartupContext> context_;
  fidl::BindingSet<fuchsia::ui::app::ViewProvider> bindings_;
  std::vector<std::unique_ptr<ViewController>> controllers_;
};

}  // namespace term

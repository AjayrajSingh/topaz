// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_
#define TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_

#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <fuchsia/webview/cpp/fidl.h>

#include <memory>

#include "lib/fidl/cpp/binding.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_ptr_set.h"
#include "lib/svc/cpp/service_provider_bridge.h"

namespace web {

class Runner;

class ComponentController : public fuchsia::sys::ComponentController,
                            public fuchsia::ui::app::ViewProvider,
                            public fuchsia::ui::viewsv1::ViewProvider {
 public:
  explicit ComponentController(Runner* runner);
  ~ComponentController();

  ComponentController(const Runner&) = delete;
  ComponentController& operator=(const Runner&) = delete;

  void Start(
      fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
      fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);

 private:
  // |fuchsia::sys::ComponentController|:
  void Kill() final;
  void Detach() final;

  // |fuchsia::ui::app::ViewProvider|:
  void CreateView(
      zx::eventpair view_token,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services)
      final;

  // |fuchsia::ui::viewsv1::ViewProvider|:
  void CreateView(
      fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner> view_owner,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) final;

  Runner* runner_;
  component::ServiceProviderBridge service_provider_;
  fidl::Binding<fuchsia::sys::ComponentController> binding_;
  fidl::BindingSet<fuchsia::ui::app::ViewProvider> view_provider_bindings_;
  fidl::BindingSet<fuchsia::ui::viewsv1::ViewProvider>
      v1_view_provider_bindings_;
  std::string url_;

  fuchsia::sys::ComponentControllerPtr web_view_controller_;
  fuchsia::ui::viewsv1::ViewProviderPtr web_view_provider_;
  fidl::InterfacePtrSet<fuchsia::webview::WebView> web_views_;
};

}  // namespace web

#endif  // TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_

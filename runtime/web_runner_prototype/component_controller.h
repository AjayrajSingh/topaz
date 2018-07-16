// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_
#define TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_

#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/views_v1/cpp/fidl.h>
#include <fuchsia/webview/cpp/fidl.h>

#include <memory>

#include "lib/fidl/cpp/binding.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_ptr_set.h"
#include "lib/svc/cpp/service_provider_bridge.h"

namespace web {
class Runner;

class ComponentController : public fuchsia::sys::ComponentController,
                            public fuchsia::ui::views_v1::ViewProvider {
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
  void Wait(WaitCallback callback) final;

  // |fuchsia::ui::views_v1::ViewProvider|:
  void CreateView(
      fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner> view_owner,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) final;

  Runner* runner_;
  component::ServiceProviderBridge service_provider_;
  fidl::Binding<fuchsia::sys::ComponentController> binding_;
  fidl::BindingSet<fuchsia::ui::views_v1::ViewProvider> view_provider_bindings_;
  std::vector<WaitCallback> wait_callbacks_;
  std::string url_;

  fuchsia::sys::ComponentControllerPtr web_view_controller_;
  fuchsia::ui::views_v1::ViewProviderPtr web_view_provider_;
  fidl::InterfacePtrSet<fuchsia::webview::WebView> web_views_;
};

}  // namespace web

#endif  // TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_COMPONENT_CONTROLLER_H_

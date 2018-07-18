// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_runner_prototype/component_controller.h"

#include "lib/component/cpp/connect.h"
#include "topaz/runtime/web_runner_prototype/runner.h"

namespace web {
constexpr char kWebView[] = "web_view";

ComponentController::ComponentController(Runner* runner)
    : runner_(runner), binding_(this) {
  service_provider_.AddService<fuchsia::ui::views_v1::ViewProvider>(
      [this](
          fidl::InterfaceRequest<fuchsia::ui::views_v1::ViewProvider> request) {
        view_provider_bindings_.AddBinding(this, std::move(request));
      });
}

ComponentController::~ComponentController() {
  if (binding_.is_bound()) {
    auto callbacks = std::move(wait_callbacks_);
    for (const auto& callback : callbacks) {
      callback(0);
    }
    binding_.events().OnTerminated(0, fuchsia::sys::TerminationReason::EXITED);
  }
}

void ComponentController::Start(
    fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  if (controller.is_valid()) {
    binding_.Bind(std::move(controller));
    binding_.set_error_handler([this] { Kill(); });
  }

  service_provider_.ServeDirectory(
      std::move(startup_info.launch_info.directory_request));

  url_ = package.resolved_url;

  component::Services services;
  fuchsia::sys::LaunchInfo launch_info;
  launch_info.url = kWebView;
  launch_info.directory_request = services.NewRequest();
  runner_->launcher()->CreateComponent(std::move(launch_info),
                                       web_view_controller_.NewRequest());
  web_view_controller_.set_error_handler([this] { Kill(); });
  services.ConnectToService(web_view_provider_.NewRequest());
}

void ComponentController::CreateView(
    fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner> view_owner,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) {
  fuchsia::sys::ServiceProviderPtr view_services;
  web_view_provider_->CreateView(std::move(view_owner),
                                 view_services.NewRequest());
  fuchsia::webview::WebViewPtr web_view;
  component::ConnectToService(view_services.get(), web_view.NewRequest());
  web_view->SetUrl(url_);
  web_views_.AddInterfacePtr(std::move(web_view));
}

void ComponentController::Kill() { runner_->DestroyComponent(this); }

void ComponentController::Detach() { binding_.set_error_handler(nullptr); }

void ComponentController::Wait(WaitCallback callback) {
  wait_callbacks_.push_back(std::move(callback));
}

}  // namespace web

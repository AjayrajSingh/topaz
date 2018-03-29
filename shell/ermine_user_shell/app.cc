// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/shell/ermine_user_shell/app.h"

#include "topaz/shell/ermine_user_shell/find_unique_ptr.h"
#include "topaz/shell/ermine_user_shell/view_controller.h"

namespace ermine_user_shell {

App::App() : context_(component::ApplicationContext::CreateFromStartupInfo()) {
  context_->outgoing_services()->AddService<views_v1::ViewProvider>(
      [this](fidl::InterfaceRequest<views_v1::ViewProvider> request) {
        bindings_.AddBinding(this, std::move(request));
      });
}

App::~App() = default;

void App::CreateView(
    fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
    fidl::InterfaceRequest<component::ServiceProvider> view_services) {
  controllers_.push_back(std::make_unique<ViewController>(
      context_->launcher().get(),
      context_->ConnectToEnvironmentService<views_v1::ViewManager>(),
      std::move(view_owner_request),
      [this](ViewController* controller) { DestroyController(controller); }));

  // TODO(abarth): Should the initial tiles be configurable?
  controllers_.back()->AddTile("term");
  controllers_.back()->AddTile("term");
  controllers_.back()->AddTile("noodles_view");
}

void App::DestroyController(ViewController* controller) {
  auto it = FindUniquePtr(controllers_.begin(), controllers_.end(), controller);
  ZX_DEBUG_ASSERT(it != controllers_.end());
  controllers_.erase(it);
}

}  // namespace ermine_user_shell

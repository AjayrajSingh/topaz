// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/app.h"

#include "examples/ui/lib/skia_font_loader.h"
#include "topaz/app/term/term_params.h"

namespace term {
namespace {

template <typename Iter, typename T>
Iter FindUniquePtr(Iter begin, Iter end, T* object) {
  return std::find_if(begin, end, [object](const std::unique_ptr<T>& other) {
    return other.get() == object;
  });
}

}  // namespace

App::App(TermParams params)
    : params_(std::move(params)),
      context_(component::StartupContext::CreateFromStartupInfo()) {
  context_->outgoing().AddPublicService<fuchsia::ui::app::ViewProvider>(
      [this](fidl::InterfaceRequest<fuchsia::ui::app::ViewProvider> request) {
        bindings_.AddBinding(this, std::move(request));
      });

  context_->outgoing().AddPublicService<fuchsia::ui::viewsv1::ViewProvider>(
      [this](
          fidl::InterfaceRequest<fuchsia::ui::viewsv1::ViewProvider> request) {
        old_bindings_.AddBinding(this, std::move(request));
      });
}

void App::CreateView(
    zx::eventpair view_token,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
    fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services) {
  auto scenic =
      context_->ConnectToEnvironmentService<fuchsia::ui::scenic::Scenic>();
  scenic::ViewContext view_context = {
      .session_and_listener_request =
          scenic::CreateScenicSessionPtrAndListenerRequest(scenic.get()),
      .view_token = std::move(view_token),
      .incoming_services = std::move(incoming_services),
      .outgoing_services = std::move(outgoing_services),
      .startup_context = context_.get(),
  };

  controllers_.push_back(std::make_unique<ViewController>(
      std::move(view_context), params_,
      [this](ViewController* controller) { DestroyController(controller); }));
}

void App::CreateView(
    fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner>
        view_owner_request,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> view_services) {
  CreateView(zx::eventpair(view_owner_request.TakeChannel().release()),
             std::move(view_services), nullptr);
}

void App::DestroyController(ViewController* controller) {
  auto it = FindUniquePtr(controllers_.begin(), controllers_.end(), controller);
  ZX_DEBUG_ASSERT(it != controllers_.end());
  controllers_.erase(it);
}

}  // namespace term

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/app.h"

#include "examples/ui/lib/skia_font_loader.h"
#include "lib/ui/view_framework/view_provider_service.h"
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
      context_(fuchsia::sys::StartupContext::CreateFromStartupInfo()) {
  context_->outgoing().AddPublicService<fuchsia::ui::views_v1::ViewProvider>(
      [this](
          fidl::InterfaceRequest<fuchsia::ui::views_v1::ViewProvider> request) {
        bindings_.AddBinding(this, std::move(request));
      });
}

App::~App() = default;

void App::CreateView(
    fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner>
        view_owner_request,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> view_services) {
  controllers_.push_back(std::make_unique<ViewController>(
      context_
          ->ConnectToEnvironmentService<fuchsia::ui::views_v1::ViewManager>(),
      std::move(view_owner_request), context_.get(), params_,
      [this](ViewController* controller) { DestroyController(controller); }));
}

void App::DestroyController(ViewController* controller) {
  auto it = FindUniquePtr(controllers_.begin(), controllers_.end(), controller);
  ZX_DEBUG_ASSERT(it != controllers_.end());
  controllers_.erase(it);
}

}  // namespace term

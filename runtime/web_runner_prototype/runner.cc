// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_runner_prototype/runner.h"

#include <utility>

#include "topaz/runtime/web_runner_prototype/component_controller.h"

namespace web {

Runner::Runner(std::unique_ptr<component::StartupContext> context)
    : context_(std::move(context)) {
  context_->outgoing().AddPublicService<fuchsia::sys::Runner>(
      [this](fidl::InterfaceRequest<fuchsia::sys::Runner> request) {
        bindings_.AddBinding(this, std::move(request));
      });
}

Runner::~Runner() {
  auto components = std::move(components_);
  for (auto component : components)
    delete component;
}

void Runner::StartComponent(
    fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  auto component = new ComponentController(this);
  component->Start(std::move(package), std::move(startup_info),
                   std::move(controller));
  components_.insert(component);
}

void Runner::DestroyComponent(ComponentController* component) {
  components_.erase(component);
  delete component;
}

}  // namespace web

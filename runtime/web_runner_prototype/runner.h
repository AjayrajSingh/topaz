// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_RUNNER_H_
#define TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_RUNNER_H_

#include <memory>
#include <set>

#include "lib/app/cpp/startup_context.h"

namespace web {
class ComponentController;

class Runner : public fuchsia::sys::Runner {
 public:
  explicit Runner(std::unique_ptr<fuchsia::sys::StartupContext> context);
  virtual ~Runner();

  Runner(const Runner&) = delete;
  Runner& operator=(const Runner&) = delete;

  fuchsia::sys::Launcher* launcher() const {
    return context_->launcher().get();
  }

  void DestroyComponent(ComponentController* component);

  // |fuchsia::sys::Runner|
  void StartComponent(fuchsia::sys::Package package,
                      fuchsia::sys::StartupInfo startup_info,
                      fidl::InterfaceRequest<fuchsia::sys::ComponentController>
                          controller) final;

 private:
  std::unique_ptr<fuchsia::sys::StartupContext> context_;
  fidl::BindingSet<fuchsia::sys::Runner> bindings_;
  std::set<ComponentController*> components_;
};

}  // namespace web

#endif  // TOPAZ_RUNTIME_WEB_RUNNER_PROTOTYPE_RUNNER_H_

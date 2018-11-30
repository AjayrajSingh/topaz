// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_

#include <memory>
#include <unordered_map>

#include <fuchsia/sys/cpp/fidl.h>

#include "component.h"
#include "flutter/fml/macros.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart/utils/vmservice_object.h"

namespace flutter {

// Publishes the |fuchsia::sys::Runner| service and runs applications on
// their own threads.
class Runner final : public fuchsia::sys::Runner {
 public:
  Runner();

  ~Runner();

 private:
  struct ActiveApplication {
    std::unique_ptr<deprecated_loop::Thread> thread;
    std::unique_ptr<Application> application;

    ActiveApplication(std::pair<std::unique_ptr<deprecated_loop::Thread>,
                                std::unique_ptr<Application>>
                          pair)
        : thread(std::move(pair.first)), application(std::move(pair.second)) {}

    ActiveApplication() = default;
  };

  std::unique_ptr<component::StartupContext> host_context_;
  fidl::BindingSet<fuchsia::sys::Runner> active_applications_bindings_;
  std::unordered_map<const Application*, ActiveApplication>
      active_applications_;

#if !defined(DART_PRODUCT)
  // The connection between the Dart VM service and The Hub.
  std::unique_ptr<fuchsia::dart::VMServiceObject> vmservice_object_;
#endif  // !defined(DART_PRODUCT)

  // |fuchsia::sys::Runner|
  void StartComponent(fuchsia::sys::Package package,
                      fuchsia::sys::StartupInfo startup_info,
                      fidl::InterfaceRequest<fuchsia::sys::ComponentController>
                          controller) override;

  void RegisterApplication(
      fidl::InterfaceRequest<fuchsia::sys::Runner> request);

  void UnregisterApplication(const Application* application);

  void OnApplicationTerminate(const Application* application);

  void SetupICU();

  FML_DISALLOW_COPY_AND_ASSIGN(Runner);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_

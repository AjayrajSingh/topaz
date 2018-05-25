// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_

#include <memory>
#include <unordered_map>

#include <component/cpp/fidl.h>

#include "component.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/macros.h"

namespace flutter {

// Publishes the |component::Runner| service and runs applications on
// their own threads.
class Runner final : public component::Runner {
 public:
  Runner();

  ~Runner();

 private:
  struct ActiveApplication {
    std::unique_ptr<fsl::Thread> thread;
    std::unique_ptr<Application> application;

    ActiveApplication(
        std::pair<std::unique_ptr<fsl::Thread>, std::unique_ptr<Application>>
            pair)
        : thread(std::move(pair.first)), application(std::move(pair.second)) {}

    ActiveApplication() = default;
  };

  std::unique_ptr<component::ApplicationContext> host_context_;
  fidl::BindingSet<component::Runner> active_applications_bindings_;
  std::unordered_map<const Application*, ActiveApplication>
      active_applications_;

  // |component::Runner|
  void StartComponent(component::Package package,
                      component::StartupInfo startup_info,
                      fidl::InterfaceRequest<component::ComponentController>
                          controller) override;

  void RegisterApplication(fidl::InterfaceRequest<component::Runner> request);

  void UnregisterApplication(const Application* application);

  void OnApplicationTerminate(const Application* application);

  void SetupICU();

  void SetupGlobalFonts();

  FXL_DISALLOW_COPY_AND_ASSIGN(Runner);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_RUNNER_H_

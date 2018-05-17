// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <memory>
#include <unordered_map>

#include <component/cpp/fidl.h>

#include "application.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/macros.h"

namespace flutter {

// Publishes the |component::ApplicationRunner| service and runs applications on
// their own threads.
class ApplicationRunner final : public component::ApplicationRunner {
 public:
  ApplicationRunner();

  ~ApplicationRunner();

 private:
  struct ActiveApplication {
    std::unique_ptr<fsl::Thread> thread;
    std::unique_ptr<Application> application;

    ActiveApplication(std::pair<std::unique_ptr<fsl::Thread>,
                                std::unique_ptr<Application>> pair)
        : thread(std::move(pair.first)), application(std::move(pair.second)) {}

    ActiveApplication() = default;
  };

  std::unique_ptr<component::ApplicationContext> host_context_;
  fidl::BindingSet<component::ApplicationRunner> active_applications_bindings_;
  std::unordered_map<const Application*, ActiveApplication>
      active_applications_;

  // |component::ApplicationRunner|
  void StartApplication(component::ApplicationPackage application,
                        component::ApplicationStartupInfo startup_info,
                        fidl::InterfaceRequest<component::ApplicationController>
                            controller) override;

  void RegisterApplication(
      fidl::InterfaceRequest<component::ApplicationRunner> request);

  void UnregisterApplication(const Application* application);

  void OnApplicationTerminate(const Application* application);

  void SetupICU();

  void SetupGlobalFonts();

  FXL_DISALLOW_COPY_AND_ASSIGN(ApplicationRunner);
};

}  // namespace flutter

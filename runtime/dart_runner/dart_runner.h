// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_
#define TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_

#include <component/cpp/fidl.h>
#include "lib/app/cpp/connect.h"
#include "lib/app/cpp/startup_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/macros.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"

namespace dart_runner {

class ControllerToken {
 public:
  explicit ControllerToken(std::string label) : label_(std::move(label)) {}
  std::string& label() { return label_; }

 private:
  std::string label_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ControllerToken);
};

class DartRunner : public component::Runner {
 public:
  explicit DartRunner();
  ~DartRunner() override;

  void PostRemoveController(ControllerToken* token);

 private:
  // |component::Runner| implementation:
  void StartComponent(component::Package package,
                      component::StartupInfo startup_info,
                      ::fidl::InterfaceRequest<component::ComponentController>
                          controller) override;

  ControllerToken* AddController(std::string label);
  void RemoveController(ControllerToken* token);
  void UpdateProcessLabel();

  std::unique_ptr<component::StartupContext> context_;
  fsl::MessageLoop* loop_;
  fidl::BindingSet<component::Runner> bindings_;
  std::vector<ControllerToken*> controllers_;
#if !defined(AOT_RUNTIME)
  MappedResource vm_snapshot_data_;
  MappedResource vm_snapshot_instructions_;
#endif

  FXL_DISALLOW_COPY_AND_ASSIGN(DartRunner);
};

}  // namespace dart_runner

#endif  // TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_

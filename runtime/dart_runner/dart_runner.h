// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_
#define TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_

#include <fuchsia/sys/cpp/fidl.h>
#include "lib/component/cpp/connect.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"
#include "topaz/runtime/dart/utils/vmservice_object.h"

namespace dart_runner {

class ControllerToken {
 public:
  explicit ControllerToken(std::string label) : label_(std::move(label)) {}
  std::string& label() { return label_; }

 private:
  std::string label_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ControllerToken);
};

class DartRunner : public fuchsia::sys::Runner {
 public:
  explicit DartRunner();
  ~DartRunner() override;

  void PostRemoveController(ControllerToken* token);

 private:
  // |fuchsia::sys::Runner| implementation:
  void StartComponent(fuchsia::sys::Package package,
                      fuchsia::sys::StartupInfo startup_info,
                      ::fidl::InterfaceRequest<fuchsia::sys::ComponentController>
                          controller) override;

  ControllerToken* AddController(std::string label);
  void RemoveController(ControllerToken* token);
  void UpdateProcessLabel();

  std::unique_ptr<component::StartupContext> context_;
  deprecated_loop::MessageLoop* loop_;
  fidl::BindingSet<fuchsia::sys::Runner> bindings_;
  std::vector<ControllerToken*> controllers_;

#if !defined(DART_PRODUCT)
  // The connection between the Dart VM service and The Hub.
  std::unique_ptr<fuchsia::dart::VMServiceObject> vmservice_object_;
#endif  // !defined(DART_PRODUCT)

#if !defined(AOT_RUNTIME)
  MappedResource vm_snapshot_data_;
  MappedResource vm_snapshot_instructions_;
#endif

  FXL_DISALLOW_COPY_AND_ASSIGN(DartRunner);
};

}  // namespace dart_runner

#endif  // TOPAZ_RUNTIME_DART_RUNNER_DART_RUNNER_H_

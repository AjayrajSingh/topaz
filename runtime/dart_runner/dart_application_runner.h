// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_RUNNER_DART_APPLICATION_RUNNER_H_
#define APPS_DART_RUNNER_DART_APPLICATION_RUNNER_H_

#include "lib/app/cpp/application_context.h"
#include "lib/app/cpp/connect.h"
#include "lib/app/fidl/application_runner.fidl.h"
#include "lib/fidl/cpp/bindings/binding.h"
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

class DartApplicationRunner : public component::ApplicationRunner {
 public:
  explicit DartApplicationRunner();
  ~DartApplicationRunner() override;

  void PostRemoveController(ControllerToken* token);

 private:
  // |component::ApplicationRunner| implementation:
  void StartApplication(
      component::ApplicationPackagePtr application,
      component::ApplicationStartupInfoPtr startup_info,
      ::f1dl::InterfaceRequest<component::ApplicationController> controller)
      override;

  ControllerToken* AddController(std::string label);
  void RemoveController(ControllerToken* token);
  void UpdateProcessLabel();

  std::unique_ptr<component::ApplicationContext> context_;
  fsl::MessageLoop* loop_;
  f1dl::BindingSet<component::ApplicationRunner> bindings_;
  std::vector<ControllerToken*> controllers_;
#if !defined(AOT_RUNTIME)
  MappedResource vm_snapshot_data_;
#endif

  FXL_DISALLOW_COPY_AND_ASSIGN(DartApplicationRunner);
};

}  // namespace dart_runner

#endif  // APPS_DART_RUNNER_DART_APPLICATION_RUNNER_H_

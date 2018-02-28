// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_DART_APPLICATION_RUNNER_H_
#define APPS_DART_CONTENT_HANDLER_DART_APPLICATION_RUNNER_H_

#include "lib/app/cpp/application_context.h"
#include "lib/app/cpp/connect.h"
#include "lib/app/fidl/application_runner.fidl.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/fxl/macros.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"

namespace dart_content_handler {

class DartApplicationRunner : public app::ApplicationRunner {
 public:
  explicit DartApplicationRunner();
  ~DartApplicationRunner() override;

 private:
  // |app::ApplicationRunner| implementation:
  void StartApplication(
      app::ApplicationPackagePtr application,
      app::ApplicationStartupInfoPtr startup_info,
      ::f1dl::InterfaceRequest<app::ApplicationController> controller) override;

  std::unique_ptr<app::ApplicationContext> context_;
  f1dl::BindingSet<app::ApplicationRunner> bindings_;
#if !defined(AOT_RUNTIME)
  MappedResource vm_snapshot_data_;
#endif

  FXL_DISALLOW_COPY_AND_ASSIGN(DartApplicationRunner);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_DART_APPLICATION_RUNNER_H_

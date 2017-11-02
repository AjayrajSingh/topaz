// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_
#define APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_

#include "lib/fxl/macros.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/app/fidl/application_runner.fidl.h"

namespace dart_content_handler {

class ApplicationRunnerImpl : public app::ApplicationRunner {
 public:
  explicit ApplicationRunnerImpl(
      fidl::InterfaceRequest<app::ApplicationRunner> app_runner);
  ~ApplicationRunnerImpl() override;

 private:
  // |app::ApplicationRunner| implementation:
  void StartApplication(app::ApplicationPackagePtr application,
                        app::ApplicationStartupInfoPtr startup_info,
                        ::fidl::InterfaceRequest<app::ApplicationController>
                            controller) override;

  fidl::Binding<app::ApplicationRunner> binding_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ApplicationRunnerImpl);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_

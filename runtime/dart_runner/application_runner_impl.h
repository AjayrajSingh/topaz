// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_
#define APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_

#include "lib/ftl/macros.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "application/services/application_runner.fidl.h"

namespace dart_content_handler {

class ApplicationRunnerImpl : public modular::ApplicationRunner {
 public:
  explicit ApplicationRunnerImpl(
      fidl::InterfaceRequest<modular::ApplicationRunner> app_runner);
  ~ApplicationRunnerImpl() override;

 private:
  // |modular::ApplicationRunner| implementation:
  void StartApplication(modular::ApplicationPackagePtr application,
                        modular::ApplicationStartupInfoPtr startup_info,
                        ::fidl::InterfaceRequest<modular::ApplicationController>
                            controller) override;

  fidl::Binding<modular::ApplicationRunner> binding_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ApplicationRunnerImpl);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_APPLICATION_RUNNER_IMPL_H_

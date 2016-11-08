// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_
#define APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

#include "apps/modular/services/application/application_runner.fidl.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/ftl/macros.h"

namespace dart_content_handler {

class DartApplicationController : public modular::ApplicationController {
 public:
  DartApplicationController(
      const std::string& url,
      fidl::Array<fidl::String> arguments,
      std::vector<char> snapshot,
      modular::ServiceProviderPtr environment_services,
      fidl::InterfaceRequest<modular::ServiceProvider> outgoing_services,
      fidl::InterfaceRequest<modular::ApplicationController> controller);
  ~DartApplicationController() override;

  void Run();

  void Kill(const KillCallback& callback) override;

  void Detach() override;

 private:
  std::string url_;
  fidl::Array<fidl::String> arguments_;
  std::vector<char> snapshot_;
  modular::ServiceProviderPtr environment_services_;
  fidl::InterfaceRequest<modular::ServiceProvider> outgoing_services_;
  fidl::Binding<modular::ApplicationController> binding_;
  Dart_Handle script_;
  Dart_Isolate isolate_;

  FTL_DISALLOW_COPY_AND_ASSIGN(DartApplicationController);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

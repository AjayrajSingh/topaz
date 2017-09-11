// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_
#define APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

#include <mxio/namespace.h>

#include "lib/svc/cpp/service_provider_bridge.h"
#include "lib/app/fidl/application_runner.fidl.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/ftl/macros.h"

namespace dart_content_handler {

class DartApplicationController : public app::ApplicationController {
 public:
  DartApplicationController(
      const uint8_t* isolate_snapshot_data,
      const uint8_t* isolate_snapshot_instructions,
#if !defined(AOT_RUNTIME)
      const uint8_t* snapshot,
      intptr_t snapshot_len,
#endif  // !defined(AOT_RUNTIME)
      app::ApplicationStartupInfoPtr startup_info,
      std::string url,
      fidl::InterfaceRequest<app::ApplicationController> controller);
  ~DartApplicationController() override;

  bool CreateIsolate();

  bool Main();
  void SendReturnCode();

 private:
  // |ApplicationController|
  void Kill() override;
  void Detach() override;
  void Wait(const WaitCallback& callback) override;

  mxio_ns_t* SetupNamespace();

  const uint8_t* isolate_snapshot_data_;
  const uint8_t* isolate_snapshot_instructions_;
#if !defined(AOT_RUNTIME)
  const uint8_t* script_snapshot_;
  intptr_t script_snapshot_len_;
#endif  // !defined(AOT_RUNTIME)
  app::ApplicationStartupInfoPtr startup_info_;
  std::string url_;
  app::ServiceProviderBridge service_provider_bridge_;
  fidl::Binding<app::ApplicationController> binding_;
  Dart_Isolate isolate_;
  int32_t return_code_ = 0;
  std::vector<WaitCallback> wait_callbacks_;

  FTL_DISALLOW_COPY_AND_ASSIGN(DartApplicationController);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

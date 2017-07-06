// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_
#define APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

#include "application/lib/svc/service_provider_bridge.h"
#include "application/services/application_runner.fidl.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/ftl/macros.h"

namespace dart_content_handler {

class DartApplicationController : public app::ApplicationController {
 public:
  DartApplicationController(
      const uint8_t* vm_snapshot_data,
      const uint8_t* vm_snapshot_instructions,
      const uint8_t* isolate_snapshot_data,
      const uint8_t* isolate_snapshot_instructions,
      std::vector<char> snapshot,
      app::ApplicationStartupInfoPtr startup_info,
      std::string url,
      fidl::InterfaceRequest<app::ApplicationController> controller);
  ~DartApplicationController() override;

  void InitDartVM();
  bool CreateIsolate();

  bool Main();

 private:
  // |ApplicationController|
  void Kill() override;
  void Detach() override;

  const uint8_t* vm_snapshot_data_;
  const uint8_t* vm_snapshot_instructions_;
  const uint8_t* isolate_snapshot_data_;
  const uint8_t* isolate_snapshot_instructions_;
  std::vector<char> script_snapshot_;
  app::ApplicationStartupInfoPtr startup_info_;
  std::string url_;
  app::ServiceProviderBridge service_provider_bridge_;
  fidl::Binding<app::ApplicationController> binding_;
  Dart_Isolate isolate_;

  FTL_DISALLOW_COPY_AND_ASSIGN(DartApplicationController);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

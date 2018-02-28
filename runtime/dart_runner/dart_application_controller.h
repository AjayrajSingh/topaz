// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_
#define APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

#include <fdio/namespace.h>

#include "lib/app/fidl/application_runner.fidl.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/fsl/vmo/sized_vmo.h"
#include "lib/fxl/macros.h"
#include "lib/svc/cpp/service_provider_bridge.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"

namespace dart_content_handler {

class DartApplicationController : public app::ApplicationController {
 public:
  DartApplicationController(
      app::ApplicationPackagePtr application,
      app::ApplicationStartupInfoPtr startup_info,
      f1dl::InterfaceRequest<app::ApplicationController> controller);
  ~DartApplicationController() override;

  bool Setup();
  bool Main();
  void SendReturnCode();

 private:
  bool SetupNamespace();

  bool SetupFromScriptSnapshot();
  bool SetupFromSource();
  bool SetupFromKernel();
  bool SetupFromSharedLibrary();

  bool CreateIsolate(void* isolate_snapshot_data,
                     void* isolate_snapshot_instructions);

  int SetupFileDescriptor(app::FileDescriptorPtr fd);

  // |ApplicationController|
  void Kill() override;
  void Detach() override;
  void Wait(const WaitCallback& callback) override;

  // Idle notification.
  void MessageEpilogue();
  async_wait_result_t OnIdleTimer(async_t* async, zx_status_t status,
                                  const zx_packet_signal* signal);

  std::string url_;
  app::ApplicationPackagePtr application_;
  app::ApplicationStartupInfoPtr startup_info_;
  app::ServiceProviderBridge service_provider_bridge_;
  f1dl::Binding<app::ApplicationController> binding_;

  fdio_ns_t* namespace_ = nullptr;
  int stdoutfd_ = -1;
  int stderrfd_ = -1;
  MappedResource isolate_snapshot_data_;
  MappedResource isolate_snapshot_instructions_;
  MappedResource script_;  // Snapshot, source or DIL file.
  void* shared_library_ = nullptr;

  Dart_Isolate isolate_;
  int32_t return_code_ = 0;
  std::vector<WaitCallback> wait_callbacks_;

  zx_time_t idle_start_ = 0;
  zx_handle_t idle_timer_ = ZX_HANDLE_INVALID;
  async::AutoWait* idle_wait_ = nullptr;

  FXL_DISALLOW_COPY_AND_ASSIGN(DartApplicationController);
};

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_DART_APPLICATION_CONTROLLER_H_

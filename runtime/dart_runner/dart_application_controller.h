// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_RUNNER_DART_APPLICATION_CONTROLLER_H_
#define APPS_DART_RUNNER_DART_APPLICATION_CONTROLLER_H_

#include <fdio/namespace.h>
#include <lib/async/cpp/wait.h>
#include <lib/zx/timer.h>

#include <component/cpp/fidl.h>
#include "lib/fidl/cpp/binding.h"
#include "lib/fsl/vmo/sized_vmo.h"
#include "lib/fxl/macros.h"
#include "lib/svc/cpp/service_provider_bridge.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"

namespace dart_runner {

class DartApplicationController : public component::ApplicationController {
 public:
  DartApplicationController(
      std::string label, component::ApplicationPackage application,
      component::StartupInfo startup_info,
      fidl::InterfaceRequest<component::ApplicationController> controller);
  ~DartApplicationController() override;

  bool Setup();
  bool Main();
  void SendReturnCode();

 private:
  bool SetupNamespace();

  bool SetupFromKernel();
  bool SetupFromSharedLibrary();

  bool CreateIsolate(void* isolate_snapshot_data,
                     void* isolate_snapshot_instructions);

  int SetupFileDescriptor(component::FileDescriptorPtr fd);

  // |ApplicationController|
  void Kill() override;
  void Detach() override;
  void Wait(WaitCallback callback) override;

  // Idle notification.
  void MessageEpilogue(Dart_Handle result);
  void OnIdleTimer(async_t* async,
                   async::WaitBase* wait,
                   zx_status_t status,
                   const zx_packet_signal* signal);

  std::string label_;
  std::string url_;
  component::ApplicationPackage application_;
  component::StartupInfo startup_info_;
  component::ServiceProviderBridge service_provider_bridge_;
  fidl::Binding<component::ApplicationController> binding_;

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

  zx::time idle_start_{0};
  zx::timer idle_timer_;
  async::WaitMethod<DartApplicationController,
                    &DartApplicationController::OnIdleTimer> idle_wait_{this};

  FXL_DISALLOW_COPY_AND_ASSIGN(DartApplicationController);
};

}  // namespace dart_runner

#endif  // APPS_DART_RUNNER_DART_APPLICATION_CONTROLLER_H_

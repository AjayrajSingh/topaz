// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_RUNNER_DART_COMPONENT_CONTROLLER_H_
#define TOPAZ_RUNTIME_DART_RUNNER_DART_COMPONENT_CONTROLLER_H_

#include <memory>

#include <lib/async/cpp/wait.h>
#include <lib/fdio/namespace.h>
#include <lib/zx/timer.h>

#include <fuchsia/sys/cpp/fidl.h>
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fsl/vmo/sized_vmo.h"
#include "lib/fxl/macros.h"
#include "lib/svc/cpp/service_provider_bridge.h"
#include "lib/svc/cpp/services.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "topaz/runtime/dart_runner/mapped_resource.h"

namespace dart_runner {

class DartComponentController : public fuchsia::sys::ComponentController {
 public:
  DartComponentController(
      std::string label, fuchsia::sys::Package package,
      fuchsia::sys::StartupInfo startup_info,
      std::shared_ptr<component::Services> runner_incoming_services,
      fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);
  ~DartComponentController() override;

  bool Setup();
  bool Main();
  void SendReturnCode();

 private:
  bool SetupNamespace();

  bool SetupFromKernel();
  bool SetupFromAppSnapshot();

  bool CreateIsolate(const uint8_t* isolate_snapshot_data,
                     const uint8_t* isolate_snapshot_instructions,
                     const uint8_t* shared_snapshot_data,
                     const uint8_t* shared_snapshot_instructions);

  int SetupFileDescriptor(fuchsia::sys::FileDescriptorPtr fd);

  // |ComponentController|
  void Kill() override;
  void Detach() override;

  // Idle notification.
  void MessageEpilogue(Dart_Handle result);
  void OnIdleTimer(async_dispatcher_t* dispatcher, async::WaitBase* wait,
                   zx_status_t status, const zx_packet_signal* signal);

  std::string label_;
  std::string url_;
  fuchsia::sys::Package package_;
  fuchsia::sys::StartupInfo startup_info_;
  std::shared_ptr<component::Services> runner_incoming_services_;
  std::string data_path_;
  fidl::Binding<fuchsia::sys::ComponentController> binding_;
  std::unique_ptr<component::StartupContext> context_;

  fdio_ns_t* namespace_ = nullptr;
  int stdoutfd_ = -1;
  int stderrfd_ = -1;
  MappedResource isolate_snapshot_data_;
  MappedResource isolate_snapshot_instructions_;
  MappedResource shared_snapshot_data_;
  MappedResource shared_snapshot_instructions_;
  std::vector<MappedResource> kernel_peices_;

  Dart_Isolate isolate_;
  int32_t return_code_ = 0;

  zx::time idle_start_{0};
  zx::timer idle_timer_;
  async::WaitMethod<DartComponentController,
                    &DartComponentController::OnIdleTimer>
      idle_wait_{this};

  FXL_DISALLOW_COPY_AND_ASSIGN(DartComponentController);
};

}  // namespace dart_runner

#endif  // TOPAZ_RUNTIME_DART_RUNNER_DART_COMPONENT_CONTROLLER_H_

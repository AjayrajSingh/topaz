// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/dart_component_controller.h"

#include <fcntl.h>
#include <lib/fdio/namespace.h>
#include <lib/fdio/util.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <zircon/status.h>
#include <zx/thread.h>
#include <zx/time.h>
#include <utility>

#include "lib/app/cpp/startup_context.h"
#include "lib/fidl/cpp/optional.h"
#include "lib/fidl/cpp/string.h"
#include "lib/fsl/vmo/file.h"
#include "lib/fxl/arraysize.h"
#include "lib/fxl/logging.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"
#include "third_party/dart/runtime/include/dart_tools_api.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart_runner/builtin_libraries.h"

using tonic::ToDart;

namespace dart_runner {
namespace {

void AfterTask() {
  tonic::DartMicrotaskQueue* queue =
      tonic::DartMicrotaskQueue::GetForCurrentThread();
  queue->RunMicrotasks();
}

}  // namespace

DartComponentController::DartComponentController(
    std::string label, fuchsia::sys::Package package,
    fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller)
    : label_(label),
      url_(std::move(package.resolved_url)),
      package_(std::move(package)),
      startup_info_(std::move(startup_info)),
      binding_(this) {
  if (controller.is_valid()) {
    binding_.Bind(std::move(controller));
    binding_.set_error_handler([this] { Kill(); });
  }

  zx_status_t status =
      zx::timer::create(ZX_TIMER_SLACK_LATE, ZX_CLOCK_MONOTONIC, &idle_timer_);
  if (status != ZX_OK) {
    FXL_LOG(INFO) << "Idle timer creation failed: "
                  << zx_status_get_string(status);
  } else {
    idle_wait_.set_object(idle_timer_.get());
    idle_wait_.set_trigger(ZX_TIMER_SIGNALED);
    idle_wait_.Begin(async_get_default());
  }
}

DartComponentController::~DartComponentController() {
  if (namespace_) {
    fdio_ns_destroy(namespace_);
    namespace_ = nullptr;
  }
  close(stdoutfd_);
  close(stderrfd_);
}

bool DartComponentController::Setup() {
  // Name the thread after the url of the component being launched.
  std::string label = "dart:" + label_;
  zx::thread::self().set_property(ZX_PROP_NAME, label.c_str(), label.size());
  Dart_SetThreadName(label.c_str());

  if (!SetupNamespace()) {
    return false;
  }

  if (SetupFromAppSnapshot()) {
    FXL_LOG(INFO) << url_ << " is running from an app snapshot";
  } else if (SetupFromKernel()) {
    FXL_LOG(INFO) << url_ << " is running from kernel";
  } else {
    FXL_LOG(ERROR) << "Could not find a program in " << url_;
    return false;
  }

  return true;
}

constexpr char kServiceRootPath[] = "/svc";

bool DartComponentController::SetupNamespace() {
  fuchsia::sys::FlatNamespace* flat = &startup_info_.flat_namespace;
  zx_status_t status = fdio_ns_create(&namespace_);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create namespace";
    return false;
  }

  for (size_t i = 0; i < flat->paths->size(); ++i) {
    if (flat->paths->at(i) == kServiceRootPath) {
      // Ownership of /svc goes to the StartupContext created below.
      continue;
    }
    zx::channel dir = std::move(flat->directories->at(i));
    zx_handle_t dir_handle = dir.release();
    const char* path = flat->paths->at(i)->data();
    status = fdio_ns_bind(namespace_, path, dir_handle);
    if (status != ZX_OK) {
      FXL_LOG(ERROR) << "Failed to bind " << flat->paths->at(i)
                     << " to namespace";
      zx_handle_close(dir_handle);
      return false;
    }
  }

  return true;
}

bool DartComponentController::SetupFromKernel() {
  MappedResource manifest;
  if (!MappedResource::LoadFromNamespace(namespace_, "pkg/data/app.dilplist",
                                         manifest)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/isolate_core_snapshot_data.bin",
          isolate_snapshot_data_)) {
    return false;
  }
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/isolate_core_snapshot_instructions.bin",
          isolate_snapshot_instructions_, true /* executable */)) {
    return false;
  }

  if (!CreateIsolate(isolate_snapshot_data_.address(),
                     isolate_snapshot_instructions_.address(), nullptr,
                     nullptr)) {
    return false;
  }

  Dart_EnterScope();

  std::string str(reinterpret_cast<const char*>(manifest.address()),
                  manifest.size());
  Dart_Handle library = Dart_Null();
  for (size_t start = 0; start < manifest.size();) {
    size_t end = str.find("\n", start);
    if (end == std::string::npos) {
      FXL_LOG(ERROR) << "Malformed manifest";
      return false;
    }

    std::string path = "pkg/data/" + str.substr(start, end - start);
    start = end + 1;

    MappedResource kernel;
    if (!MappedResource::LoadFromNamespace(namespace_, path, kernel)) {
      return false;
    }
    library = Dart_LoadLibraryFromKernel(kernel.address(), kernel.size());
    if (Dart_IsError(library)) {
      FXL_LOG(ERROR) << "Failed to load kernel: " << Dart_GetError(library);
      Dart_ExitScope();
      return false;
    }

    kernel_peices_.emplace_back(std::move(kernel));
  }
  Dart_SetRootLibrary(library);

  Dart_Handle result = Dart_FinalizeLoading(false);
  if (Dart_IsError(result)) {
    FXL_LOG(ERROR) << "Failed to FinalizeLoading: " << Dart_GetError(result);
    Dart_ExitScope();
    return false;
  }

  return true;
}

bool DartComponentController::SetupFromAppSnapshot() {
#if !defined(AOT_RUNTIME)
  // If we start generating app-jit snapshots, the code below should be able
  // handle that case without modification.
  return false;
#else

  if (!MappedResource::LoadFromNamespace(namespace_,
                                         "pkg/data/isolate_snapshot_data.bin",
                                         isolate_snapshot_data_)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(
          namespace_, "pkg/data/isolate_snapshot_instructions.bin",
          isolate_snapshot_instructions_, true /* executable */)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(namespace_,
                                         "pkg/data/shared_snapshot_data.bin",
                                         shared_snapshot_data_)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(
          namespace_, "pkg/data/shared_snapshot_instructions.bin",
          shared_snapshot_instructions_, true /* executable */)) {
    return false;
  }

  return CreateIsolate(isolate_snapshot_data_.address(),
                       isolate_snapshot_instructions_.address(),
                       shared_snapshot_data_.address(),
                       shared_snapshot_instructions_.address());
#endif  // defined(AOT_RUNTIME)
}

int DartComponentController::SetupFileDescriptor(
    fuchsia::sys::FileDescriptorPtr fd) {
  if (!fd) {
    return -1;
  }
  zx_handle_t handles[3] = {
      fd->handle0.release(),
      fd->handle1.release(),
      fd->handle2.release(),
  };
  uint32_t htypes[3] = {
      static_cast<uint32_t>(fd->type0),
      static_cast<uint32_t>(fd->type1),
      static_cast<uint32_t>(fd->type2),
  };
  int valid_handle_count = 0;
  for (int i = 0; i < 3; i++) {
    valid_handle_count += (handles[i] == ZX_HANDLE_INVALID) ? 0 : 1;
  }
  if (valid_handle_count == 0) {
    return -1;
  }

  int outfd;
  zx_status_t status =
      fdio_create_fd(handles, htypes, valid_handle_count, &outfd);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to extract output fd: "
                   << zx_status_get_string(status);
    return -1;
  }
  return outfd;
}

bool DartComponentController::CreateIsolate(
    const uint8_t* isolate_snapshot_data,
    const uint8_t* isolate_snapshot_instructions,
    const uint8_t* shared_snapshot_data,
    const uint8_t* shared_snapshot_instructions) {
  // Create the isolate from the snapshot.
  char* error = nullptr;

  // TODO(dart_runner): Pass if we start using tonic's loader.
  intptr_t namespace_fd = -1;
  // Freed in IsolateShutdownCallback.
  auto state = new tonic::DartState(
      namespace_fd, [this](Dart_Handle result) { MessageEpilogue(result); });

  isolate_ = Dart_CreateIsolate(
      url_.c_str(), label_.c_str(), isolate_snapshot_data,
      isolate_snapshot_instructions, shared_snapshot_data,
      shared_snapshot_instructions, nullptr /* flags */, state, &error);
  if (!isolate_) {
    FXL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return false;
  }

  state->SetIsolate(isolate_);

  state->message_handler().Initialize(
      deprecated_loop::MessageLoop::GetCurrent()->task_runner());

  state->SetReturnCodeCallback(
      [this](uint32_t return_code) { return_code_ = return_code; });

  return true;
}

bool DartComponentController::Main() {
  Dart_EnterScope();

  tonic::DartMicrotaskQueue::StartForCurrentThread();
  deprecated_loop::MessageLoop::GetCurrent()->SetAfterTaskCallback(AfterTask);

  fidl::VectorPtr<fidl::StringPtr> arguments =
      std::move(startup_info_.launch_info.arguments);

  // TODO(abarth): Remove service_provider_bridge once we have an
  // implementation of rio.Directory in Dart.
  if (startup_info_.launch_info.directory_request.is_valid()) {
    service_provider_bridge_.ServeDirectory(
        std::move(startup_info_.launch_info.directory_request));
  }

  fuchsia::sys::ServiceProviderPtr service_provider;
  auto outgoing_services = service_provider.NewRequest();
  service_provider_bridge_.set_backend(std::move(service_provider));

  stdoutfd_ = SetupFileDescriptor(std::move(startup_info_.launch_info.out));
  stderrfd_ = SetupFileDescriptor(std::move(startup_info_.launch_info.err));

  InitBuiltinLibrariesForIsolate(
      url_, namespace_, stdoutfd_, stderrfd_,
      fuchsia::sys::StartupContext::CreateFrom(std::move(startup_info_)),
      std::move(outgoing_services), false /* service_isolate */);
  namespace_ = nullptr;

  Dart_ExitScope();
  Dart_ExitIsolate();
  char* error = Dart_IsolateMakeRunnable(isolate_);
  if (error != nullptr) {
    Dart_EnterIsolate(isolate_);
    Dart_ShutdownIsolate();
    FXL_LOG(ERROR) << "Unable to make isolate runnable: " << error;
    free(error);
    return false;
  }
  Dart_EnterIsolate(isolate_);
  Dart_EnterScope();

  Dart_Handle dart_arguments =
      Dart_NewListOf(Dart_CoreType_String, arguments->size());
  if (Dart_IsError(dart_arguments)) {
    FXL_LOG(ERROR) << "Failed to allocate Dart arguments list: "
                   << Dart_GetError(dart_arguments);
    Dart_ExitScope();
    return false;
  }
  for (size_t i = 0; i < arguments->size(); i++) {
    tonic::LogIfError(
        Dart_ListSetAt(dart_arguments, i, ToDart(arguments->at(i).get())));
  }

  Dart_Handle argv[] = {
      dart_arguments,
  };

  Dart_Handle main_result =
      Dart_Invoke(Dart_RootLibrary(), ToDart("main"), arraysize(argv), argv);
  if (Dart_IsError(main_result)) {
    auto dart_state = tonic::DartState::Current();
    if (!dart_state->has_set_return_code()) {
      // The program hasn't set a return code meaning this exit is unexpected.
      FXL_LOG(ERROR) << Dart_GetError(main_result);
      return_code_ = tonic::GetErrorExitCode(main_result);
    }
    Dart_ExitScope();
    return false;
  }

  Dart_ExitScope();
  return true;
}

void DartComponentController::Kill() {
  if (Dart_CurrentIsolate()) {
    deprecated_loop::MessageLoop::GetCurrent()->SetAfterTaskCallback(nullptr);
    tonic::DartMicrotaskQueue::GetForCurrentThread()->Destroy();

    deprecated_loop::MessageLoop::GetCurrent()->QuitNow();

    // TODO(rosswang): The docs warn of threading issues if doing this again,
    // but without this, attempting to shut down the isolate finalizes app
    // contexts that can't tell a shutdown is in progress and so fatal.
    Dart_SetMessageNotifyCallback(nullptr);

    Dart_ShutdownIsolate();
  }
}

void DartComponentController::Detach() {
  binding_.set_error_handler(fit::closure());
}

void DartComponentController::Wait(WaitCallback callback) {
  wait_callbacks_.push_back(callback);
}

void DartComponentController::SendReturnCode() {
  for (const auto& iter : wait_callbacks_) {
    iter(return_code_);
  }
  wait_callbacks_.clear();
}

const zx::duration kIdleWaitDuration = zx::sec(2);
const zx::duration kIdleNotifyDuration = zx::msec(500);
const zx::duration kIdleSlack = zx::sec(1);

void DartComponentController::MessageEpilogue(Dart_Handle result) {
  auto dart_state = tonic::DartState::Current();
  // If the Dart program has set a return code, then it is intending to shut
  // down by way of a fatal error, and so there is no need to override
  // return_code_.
  if (dart_state->has_set_return_code()) {
    Dart_ShutdownIsolate();
    return;
  }

  // Otherwise, see if there was any other error.
  return_code_ = tonic::GetErrorExitCode(result);
  if (return_code_ != 0) {
    Dart_ShutdownIsolate();
    return;
  }

  idle_start_ = zx::clock::get_monotonic();
  zx_status_t status =
      idle_timer_.set(idle_start_ + kIdleWaitDuration, kIdleSlack);
  if (status != ZX_OK) {
    FXL_LOG(INFO) << "Idle timer set failed: " << zx_status_get_string(status);
  }
}

void DartComponentController::OnIdleTimer(async_t* async, async::WaitBase* wait,
                                          zx_status_t status,
                                          const zx_packet_signal* signal) {
  if ((status != ZX_OK) || !(signal->observed & ZX_TIMER_SIGNALED) ||
      !Dart_CurrentIsolate()) {
    // Timer closed or isolate shutdown.
    return;
  }

  zx::time deadline = idle_start_ + kIdleWaitDuration;
  zx::time now = zx::clock::get_monotonic();
  if (now >= deadline) {
    // No Dart message has been processed for kIdleWaitDuration: assume we'll
    // stay idle for kIdleNotifyDuration.
    Dart_NotifyIdle((now + kIdleNotifyDuration).get());
    idle_start_ = zx::time(0);
    idle_timer_.cancel();  // De-assert signal.
  } else {
    // Early wakeup or message pushed idle time forward: reschedule.
    zx_status_t status = idle_timer_.set(deadline, kIdleSlack);
    if (status != ZX_OK) {
      FXL_LOG(INFO) << "Idle timer set failed: "
                    << zx_status_get_string(status);
    }
  }
  wait->Begin(async);  // ignore errors
}

}  // namespace dart_runner

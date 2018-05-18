// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/dart_application_controller.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <fdio/namespace.h>
#include <fdio/util.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <zircon/dlfcn.h>
#include <zircon/status.h>
#include <zx/thread.h>
#include <zx/time.h>
#include <utility>

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/optional.h"
#include "lib/fidl/cpp/string.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fsl/vmo/file.h"
#include "lib/fxl/arraysize.h"
#include "lib/fxl/logging.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"
#include "third_party/dart/runtime/include/dart_tools_api.h"
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

DartApplicationController::DartApplicationController(
    std::string label,
    component::ApplicationPackage application,
    component::ApplicationStartupInfo startup_info,
    fidl::InterfaceRequest<component::ApplicationController> controller)
    : label_(label),
      url_(std::move(application.resolved_url)),
      application_(std::move(application)),
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

DartApplicationController::~DartApplicationController() {
  if (namespace_) {
    fdio_ns_destroy(namespace_);
    namespace_ = nullptr;
  }
  if (shared_library_) {
    dlclose(shared_library_);
    shared_library_ = nullptr;
  }
  close(stdoutfd_);
  close(stderrfd_);
}

bool DartApplicationController::Setup() {
  // Name the thread after the url of the application being launched.
  std::string label = "dart:" + label_;
  zx::thread::self().set_property(ZX_PROP_NAME, label.c_str(), label.size());
  Dart_SetThreadName(label.c_str());

  if (!SetupNamespace()) {
    return false;
  }

  if (SetupFromSharedLibrary()) {
    FXL_LOG(INFO) << url_ << " is running from a shared library";
  } else if (SetupFromKernel()) {
    FXL_LOG(INFO) << url_ << " is running from kernel";
  } else {
    FXL_LOG(ERROR) << "Could not find a program in " << url_;
    return false;
  }

  return true;
}

constexpr char kServiceRootPath[] = "/svc";

bool DartApplicationController::SetupNamespace() {
  component::FlatNamespace* flat = &startup_info_.flat_namespace;
  zx_status_t status = fdio_ns_create(&namespace_);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create namespace";
    return false;
  }

  for (size_t i = 0; i < flat->paths->size(); ++i) {
    if (flat->paths->at(i) == kServiceRootPath) {
      // Ownership of /svc goes to the ApplicationContext created below.
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

bool DartApplicationController::SetupFromKernel() {
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
                     isolate_snapshot_instructions_.address())) {
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

    // TODO(rmacnak): Keep these in memory and remove copying from the VM.
    MappedResource kernel;
    if (!MappedResource::LoadFromNamespace(namespace_, path, kernel)) {
      return false;
    }
    library = Dart_LoadLibraryFromKernel(
        reinterpret_cast<const uint8_t*>(kernel.address()), kernel.size());
    if (Dart_IsError(library)) {
      FXL_LOG(ERROR) << "Failed to load kernel: " << Dart_GetError(library);
      Dart_ExitScope();
      return false;
    }
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

bool DartApplicationController::SetupFromSharedLibrary() {
#if !defined(AOT_RUNTIME)
  // If we start generating app-jit snapshots, the code below should be able
  // handle that case without modification.
  return false;
#else
  const std::string& path = "pkg/data/libapp.so";

  fxl::UniqueFD root_dir(fdio_ns_opendir(namespace_));
  if (!root_dir.is_valid()) {
    FXL_LOG(ERROR) << "Failed to open namespace";
    return false;
  }

  fsl::SizedVmo dylib;
  if (!fsl::VmoFromFilenameAt(root_dir.get(), path, &dylib)) {
    FXL_LOG(ERROR) << "Failed to read " << path;
    return false;
  }

  dlerror();
  shared_library_ = dlopen_vmo(dylib.vmo().get(), RTLD_LAZY);
  if (shared_library_ == nullptr) {
    FXL_LOG(ERROR) << "dlopen failed: " << dlerror();
    return false;
  }

  void* isolate_snapshot_data =
      dlsym(shared_library_, "_kDartIsolateSnapshotData");
  if (isolate_snapshot_data == nullptr) {
    FXL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotData) failed: " << dlerror();
    return false;
  }

  void* isolate_snapshot_instructions =
      dlsym(shared_library_, "_kDartIsolateSnapshotInstructions");
  if (isolate_snapshot_instructions == nullptr) {
    FXL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotInstructions) failed: "
                   << dlerror();
    return false;
  }

  if (!CreateIsolate(isolate_snapshot_data, isolate_snapshot_instructions)) {
    return false;
  }

  return true;
#endif  // defined(AOT_RUNTIME)
}

int DartApplicationController::SetupFileDescriptor(
    component::FileDescriptorPtr fd) {
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

bool DartApplicationController::CreateIsolate(
    void* isolate_snapshot_data,
    void* isolate_snapshot_instructions) {
  // Create the isolate from the snapshot.
  char* error = nullptr;

  // TODO(dart_runner): Pass if we start using tonic's loader.
  intptr_t namespace_fd = -1;
  // Freed in IsolateShutdownCallback.
  auto state = new tonic::DartState(namespace_fd,
      [this](Dart_Handle result) { MessageEpilogue(result); });

  isolate_ = Dart_CreateIsolate(
      url_.c_str(), label_.c_str(),
      reinterpret_cast<const uint8_t*>(isolate_snapshot_data),
      reinterpret_cast<const uint8_t*>(isolate_snapshot_instructions), nullptr,
      nullptr, nullptr, state, &error);
  if (!isolate_) {
    FXL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return false;
  }

  state->SetIsolate(isolate_);

  state->message_handler().Initialize(
      fsl::MessageLoop::GetCurrent()->task_runner());

  state->SetReturnCodeCallback(
      [this](uint32_t return_code) { return_code_ = return_code; });

  return true;
}

bool DartApplicationController::Main() {
  Dart_EnterScope();

  tonic::DartMicrotaskQueue::StartForCurrentThread();
  fsl::MessageLoop::GetCurrent()->SetAfterTaskCallback(AfterTask);

  fidl::VectorPtr<fidl::StringPtr> arguments =
      std::move(startup_info_.launch_info.arguments);

  // TODO(abarth): Remove service_provider_bridge once we have an
  // implementation of rio.Directory in Dart.
  if (startup_info_.launch_info.directory_request.is_valid()) {
    service_provider_bridge_.ServeDirectory(
        std::move(startup_info_.launch_info.directory_request));
  }

  component::ServiceProviderPtr service_provider;
  auto outgoing_services = service_provider.NewRequest();
  service_provider_bridge_.set_backend(std::move(service_provider));

  stdoutfd_ = SetupFileDescriptor(std::move(startup_info_.launch_info.out));
  stderrfd_ = SetupFileDescriptor(std::move(startup_info_.launch_info.err));

  InitBuiltinLibrariesForIsolate(
      url_, namespace_, stdoutfd_, stderrfd_,
      component::ApplicationContext::CreateFrom(std::move(startup_info_)),
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

  Dart_Handle dart_arguments = Dart_NewList(arguments->size());
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
    FXL_LOG(ERROR) << Dart_GetError(main_result);
    return_code_ = tonic::GetErrorExitCode(main_result);
    Dart_ExitScope();
    return false;
  }

  Dart_ExitScope();
  return true;
}

void DartApplicationController::Kill() {
  if (Dart_CurrentIsolate()) {
    fsl::MessageLoop::GetCurrent()->SetAfterTaskCallback(nullptr);
    tonic::DartMicrotaskQueue::GetForCurrentThread()->Destroy();

    fsl::MessageLoop::GetCurrent()->QuitNow();

    // TODO(rosswang): The docs warn of threading issues if doing this again,
    // but without this, attempting to shut down the isolate finalizes app
    // contexts that can't tell a shutdown is in progress and so fatal.
    Dart_SetMessageNotifyCallback(nullptr);

    Dart_ShutdownIsolate();
  }
}

void DartApplicationController::Detach() {
  binding_.set_error_handler(fxl::Closure());
}

void DartApplicationController::Wait(WaitCallback callback) {
  wait_callbacks_.push_back(callback);
}

void DartApplicationController::SendReturnCode() {
  for (const auto& iter : wait_callbacks_) {
    iter(return_code_);
  }
  wait_callbacks_.clear();
}

const zx::duration kIdleWaitDuration = zx::sec(2);
const zx::duration kIdleNotifyDuration = zx::msec(500);
const zx::duration kIdleSlack = zx::sec(1);

void DartApplicationController::MessageEpilogue(Dart_Handle result) {
  auto dart_state = tonic::DartState::Current();
  // If the Dart program has set a return code, then it is intending to shut
  // down by way of a fatal error, and so there is no need to override
  // return_code_.
  if (dart_state->has_set_return_code() && Dart_IsError(result) &&
      Dart_IsFatalError(result)) {
    Dart_ShutdownIsolate();
    return;
  }

  // Otherwise, see if there was any other error.
  return_code_ = tonic::GetErrorExitCode(result);
  if (return_code_ != 0) {
    Dart_ShutdownIsolate();
    return;
  }

  idle_start_ = zx::clock::get(ZX_CLOCK_MONOTONIC);
  zx_status_t status =
      idle_timer_.set(idle_start_ + kIdleWaitDuration, kIdleSlack);
  if (status != ZX_OK) {
    FXL_LOG(INFO) << "Idle timer set failed: " << zx_status_get_string(status);
  }
}

void DartApplicationController::OnIdleTimer(async_t* async,
                                            async::WaitBase* wait,
                                            zx_status_t status,
                                            const zx_packet_signal* signal) {
  if ((status != ZX_OK) || !(signal->observed & ZX_TIMER_SIGNALED) ||
      !Dart_CurrentIsolate()) {
    // Timer closed or isolate shutdown.
    return;
  }

  zx::time deadline = idle_start_ + kIdleWaitDuration;
  zx::time now = zx::clock::get(ZX_CLOCK_MONOTONIC);
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

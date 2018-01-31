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
#include <zx/process.h>
#include <zx/thread.h>
#include <utility>

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/bindings/string.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fsl/vmo/file.h"
#include "lib/fxl/arraysize.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/synchronization/mutex.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"
#include "third_party/dart/runtime/include/dart_tools_api.h"
#include "topaz/runtime/dart_runner/builtin_libraries.h"

using tonic::ToDart;

namespace dart_content_handler {
namespace {

void AfterTask() {
  tonic::DartMicrotaskQueue* queue =
      tonic::DartMicrotaskQueue::GetForCurrentThread();
  queue->RunMicrotasks();
}

std::string GetLabelFromURL(const std::string& url) {
  size_t last_slash = url.rfind('/');
  if (last_slash == std::string::npos || last_slash + 1 == url.length())
    return url;
  return url.substr(last_slash + 1);
}

void NopReleaseDill(uint8_t* dill) {
  // Released by ~MappedResource.
}

}  // namespace

DartApplicationController::DartApplicationController(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    fidl::InterfaceRequest<app::ApplicationController> controller)
    : url_(std::move(application->resolved_url)),
      application_(std::move(application)),
      startup_info_(std::move(startup_info)),
      binding_(this) {
  if (controller.is_valid()) {
    binding_.Bind(std::move(controller));
    binding_.set_error_handler([this] { Kill(); });
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
  // Name the process and thread after the url of the application being
  // launched.
  std::string label = "dart:" + GetLabelFromURL(url_);
  zx::process::self().set_property(ZX_PROP_NAME, label.c_str(), label.size());
  zx::thread::self().set_property(ZX_PROP_NAME, label.c_str(), label.size());
  Dart_SetThreadName(label.c_str());

  if (!SetupNamespace()) {
    return false;
  }

  if (SetupFromScriptSnapshot()) {
    FXL_LOG(INFO) << url_ << " is running from a script snapshot";
  } else if (SetupFromSource()) {
    FXL_LOG(INFO) << url_ << " is running from source";
  } else if (SetupFromSharedLibrary()) {
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
  app::FlatNamespacePtr& flat = *(&startup_info_->flat_namespace);
  zx_status_t status = fdio_ns_create(&namespace_);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create namespace";
    return false;
  }

  for (size_t i = 0; i < flat->paths.size(); ++i) {
    if (flat->paths[i] == kServiceRootPath) {
      // Ownership of /svc goes to the ApplicationContext created below.
      continue;
    }
    zx::channel dir = std::move(flat->directories[i]);
    zx_handle_t dir_handle = dir.release();
    const char* path = flat->paths[i].data();
    status = fdio_ns_bind(namespace_, path, dir_handle);
    if (status != ZX_OK) {
      FXL_LOG(ERROR) << "Failed to bind " << flat->paths[i] << " to namespace";
      zx_handle_close(dir_handle);
      return false;
    }
  }

  return true;
}

bool DartApplicationController::SetupFromScriptSnapshot() {
#if defined(AOT_RUNTIME)
  return false;
#else
  if (!MappedResource::LoadFromNamespace(
          namespace_, "pkg/data/snapshot_blob.bin", script_)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/snapshot_isolate.bin", isolate_snapshot_data_)) {
    return false;
  }

  if (!CreateIsolate(isolate_snapshot_data_.address(), nullptr)) {
    return false;
  }

  Dart_EnterScope();
  Dart_Handle root_library = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<const uint8_t*>(script_.address()), script_.size());
  if (Dart_IsError(root_library)) {
    FXL_LOG(ERROR) << "Failed to load script snapshot: "
                   << Dart_GetError(root_library);
    Dart_ExitScope();
    return false;
  }

  return true;
#endif  // !defined(AOT_RUNTIME)
}

bool DartApplicationController::SetupFromSource() {
#if defined(AOT_RUNTIME)
  return false;
#else
  if (!application_->data ||
      !MappedResource::LoadFromVmo(
          url_,
          fsl::SizedVmo(std::move(application_->data->vmo),
                        application_->data->size),
          script_)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/snapshot_isolate.bin", isolate_snapshot_data_)) {
    return false;
  }

  if (!CreateIsolate(isolate_snapshot_data_.address(), nullptr)) {
    return false;
  }

  Dart_Handle status =
      Dart_SetLibraryTagHandler(tonic::DartState::HandleLibraryTag);
  if (Dart_IsError(status)) {
    FXL_LOG(ERROR) << "Dart_SetLibraryTagHandler failed: "
                   << Dart_GetError(status);
    return false;
  }

  Dart_EnterScope();
  Dart_Handle url = Dart_NewStringFromUTF8(
      reinterpret_cast<const uint8_t*>(url_.data()), url_.length());
  if (Dart_IsError(url)) {
    FXL_LOG(ERROR) << "Failed to make string for url: " << Dart_GetError(url);
    Dart_ExitScope();
    return false;
  }

  Dart_Handle script = Dart_NewStringFromUTF8(
      reinterpret_cast<const uint8_t*>(script_.address()), script_.size());
  if (Dart_IsError(script)) {
    FXL_LOG(ERROR) << "Failed to make string for script: "
                   << Dart_GetError(script);
    Dart_ExitScope();
    return false;
  }
  Dart_Handle root_library = Dart_LoadScript(url, url, script, 0, 0);
  if (Dart_IsError(root_library)) {
    FXL_LOG(ERROR) << "Failed to load script: " << Dart_GetError(root_library);
    Dart_ExitScope();
    return false;
  }

  return true;
#endif  // !defined(AOT_RUNTIME)
}

bool DartApplicationController::SetupFromKernel() {
  if (!MappedResource::LoadFromNamespace(
          namespace_, "pkg/data/kernel_blob.dill", script_)) {
    return false;
  }

  if (!MappedResource::LoadFromNamespace(nullptr, "pkg/data/platform.dill",
                                         platform_dill_)) {
    return false;
  }

  if (!CreateIsolateFromKernel()) {
    return false;
  }

  Dart_EnterScope();
  Dart_Handle root_library = Dart_LoadKernel(
      Dart_ReadKernelBinary(reinterpret_cast<const uint8_t*>(script_.address()),
                            script_.size(), NopReleaseDill));
  if (Dart_IsError(root_library)) {
    FXL_LOG(ERROR) << "Failed to load script kernel: "
                   << Dart_GetError(root_library);
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

int DartApplicationController::SetupFileDescriptor(app::FileDescriptorPtr fd) {
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
  zx_status_t status = fdio_create_fd(handles, htypes, valid_handle_count,
                                      &outfd);
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

  auto state = new tonic::DartState();  // Freed in IsolateShutdownCallback.
  isolate_ = Dart_CreateIsolate(
      url_.c_str(), "main",
      reinterpret_cast<const uint8_t*>(isolate_snapshot_data),
      reinterpret_cast<const uint8_t*>(isolate_snapshot_instructions), nullptr,
      state, &error);
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

bool DartApplicationController::CreateIsolateFromKernel() {
  void* platform_kernel = Dart_ReadKernelBinary(
      reinterpret_cast<const uint8_t*>(platform_dill_.address()),
      platform_dill_.size(), NopReleaseDill);

  // Create the isolate from the snapshot.
  char* error = nullptr;

  auto state = new tonic::DartState();  // Freed in IsolateShutdownCallback.
  isolate_ = Dart_CreateIsolateFromKernel(url_.c_str(), "main", platform_kernel,
                                          nullptr, state, &error);
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

  Dart_Handle root_library = Dart_RootLibrary();

  // TODO(jeffbrown): Decide what we should do with any startup handles.
  // eg. Redirect stdin, stdout, and stderr.

  tonic::DartMicrotaskQueue::StartForCurrentThread();
  fsl::MessageLoop::GetCurrent()->SetAfterTaskCallback(AfterTask);

  fidl::Array<fidl::String> arguments =
      std::move(startup_info_->launch_info->arguments);

  if (startup_info_->launch_info->services) {
    service_provider_bridge_.AddBinding(
        std::move(startup_info_->launch_info->services));
  }

  // TODO(abarth): Remove service_provider_bridge once we have an
  // implementation of rio.Directory in Dart.
  if (startup_info_->launch_info->service_request.is_valid()) {
    service_provider_bridge_.ServeDirectory(
        std::move(startup_info_->launch_info->service_request));
  }

  app::ServiceProviderPtr service_provider;
  auto outgoing_services = service_provider.NewRequest();
  service_provider_bridge_.set_backend(std::move(service_provider));

  stdoutfd_ = SetupFileDescriptor(std::move(startup_info_->launch_info->out));
  stderrfd_ = SetupFileDescriptor(std::move(startup_info_->launch_info->err));

  InitBuiltinLibrariesForIsolate(
      url_, namespace_, stdoutfd_, stderrfd_,
      app::ApplicationContext::CreateFrom(std::move(startup_info_)),
      std::move(outgoing_services));
  namespace_ = nullptr;

  Dart_Handle dart_arguments = Dart_NewList(arguments.size());
  if (Dart_IsError(dart_arguments)) {
    FXL_LOG(ERROR) << "Failed to allocate Dart arguments list: "
                   << Dart_GetError(dart_arguments);
    Dart_ExitScope();
    return false;
  }
  for (size_t i = 0; i < arguments.size(); i++) {
    tonic::LogIfError(
        Dart_ListSetAt(dart_arguments, i, ToDart(arguments[i].get())));
  }

  Dart_Handle argv[] = {
      dart_arguments,
  };

  Dart_Handle main =
      Dart_Invoke(root_library, ToDart("main"), arraysize(argv), argv);
  if (Dart_IsError(main)) {
    FXL_LOG(ERROR) << Dart_GetError(main);
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

void DartApplicationController::Wait(const WaitCallback& callback) {
  wait_callbacks_.push_back(callback);
}

void DartApplicationController::SendReturnCode() {
  for (const auto& iter : wait_callbacks_) {
    iter(return_code_);
  }
  wait_callbacks_.clear();
}

}  // namespace dart_content_handler

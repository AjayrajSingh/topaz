// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application_controller.h"

#include <fcntl.h>
#include <zircon/status.h>
#include <fdio/namespace.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <utility>

#include "lib/app/cpp/application_context.h"
#include "apps/dart_content_handler/builtin_libraries.h"
#include "lib/fidl/cpp/bindings/string.h"
#include "lib/fxl/arraysize.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/synchronization/mutex.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"

using tonic::ToDart;

namespace dart_content_handler {
namespace {

void AfterTask() {
  tonic::DartMicrotaskQueue* queue =
      tonic::DartMicrotaskQueue::GetForCurrentThread();
  queue->RunMicrotasks();
}

}  // namespace

DartApplicationController::DartApplicationController(
    const uint8_t* isolate_snapshot_data,
    const uint8_t* isolate_snapshot_instructions,
#if !defined(AOT_RUNTIME)
    const uint8_t* script_snapshot,
    intptr_t script_snapshot_len,
#endif  // !defined(AOT_RUNTIE)
    app::ApplicationStartupInfoPtr startup_info,
    std::string url,
    fidl::InterfaceRequest<app::ApplicationController> controller)
    : isolate_snapshot_data_(isolate_snapshot_data),
      isolate_snapshot_instructions_(isolate_snapshot_instructions),
#if !defined(AOT_RUNTIME)
      script_snapshot_(script_snapshot),
      script_snapshot_len_(script_snapshot_len),
#endif  // !defined(AOT_RUNTIE)
      startup_info_(std::move(startup_info)),
      url_(std::move(url)),
      binding_(this) {
  if (controller.is_pending()) {
    binding_.Bind(std::move(controller));
    binding_.set_connection_error_handler([this] { Kill(); });
  }
}

DartApplicationController::~DartApplicationController() {}

bool DartApplicationController::CreateIsolate() {
  // Create the isolate from the snapshot.
  char* error = nullptr;

  auto state = new tonic::DartState();  // Freed in IsolateShutdownCallback.
  isolate_ = Dart_CreateIsolate(url_.c_str(), "main", isolate_snapshot_data_,
                                isolate_snapshot_instructions_, nullptr, state,
                                &error);
  if (!isolate_) {
    FXL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return false;
  }

  state->SetIsolate(isolate_);

  state->message_handler().Initialize(
      fsl::MessageLoop::GetCurrent()->task_runner());

  state->SetReturnCodeCallback([this](uint32_t return_code) {
    return_code_ = return_code;
  });

  return true;
}

constexpr char kServiceRootPath[] = "/svc";

fdio_ns_t* DartApplicationController::SetupNamespace() {
  fdio_ns_t* fdio_namespc;
  const app::FlatNamespacePtr& flat = startup_info_->flat_namespace;
  zx_status_t status = fdio_ns_create(&fdio_namespc);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create namespace";
    return nullptr;
  }
  for (size_t i = 0; i < flat->paths.size(); ++i) {
    if (flat->paths[i] == kServiceRootPath) {
      // Ownership of /svc goes to the ApplicationContext created below.
      continue;
    }
    zx::channel dir = std::move(flat->directories[i]);
    zx_handle_t dir_handle = dir.release();
    const char* path = flat->paths[i].data();
    status = fdio_ns_bind(fdio_namespc, path, dir_handle);
    if (status != ZX_OK) {
      FXL_LOG(ERROR) << "Failed to bind " << flat->paths[i] << " to namespace";
      zx_handle_close(dir_handle);
      fdio_ns_destroy(fdio_namespc);
      return nullptr;
    }
  }
  return fdio_namespc;
}

bool DartApplicationController::Main() {
  Dart_EnterScope();

#if defined(AOT_RUNTIME)
  Dart_Handle root_library = Dart_RootLibrary();
#else
  Dart_Handle root_library =
      Dart_LoadScriptFromSnapshot(script_snapshot_, script_snapshot_len_);
#endif

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

  fdio_ns_t* fdio_namespc = SetupNamespace();
  if (fdio_namespc == nullptr)
    return false;

  InitBuiltinLibrariesForIsolate(
      url_, fdio_namespc,
      app::ApplicationContext::CreateFrom(std::move(startup_info_)),
      std::move(outgoing_services));

  Dart_Handle dart_arguments = Dart_NewList(arguments.size());
  if (Dart_IsError(dart_arguments)) {
    FXL_LOG(ERROR) << "Failed to allocate Dart arguments list";
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
  binding_.set_connection_error_handler(fxl::Closure());
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

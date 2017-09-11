// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application_controller.h"

#include <fcntl.h>
#include <magenta/status.h>
#include <mxio/namespace.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <utility>

#include "lib/app/cpp/application_context.h"
#include "apps/dart_content_handler/builtin_libraries.h"
#include "lib/fidl/cpp/bindings/string.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/ftl/synchronization/mutex.h"
#include "lib/mtl/tasks/message_loop.h"
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
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return false;
  }

  state->SetIsolate(isolate_);

  state->message_handler().Initialize(
      mtl::MessageLoop::GetCurrent()->task_runner());

  state->SetReturnCodeCallback([this](uint32_t return_code) {
    return_code_ = return_code;
  });

  return true;
}

constexpr char kServiceRootPath[] = "/svc";

mxio_ns_t* DartApplicationController::SetupNamespace() {
  mxio_ns_t* mxio_namespc;
  const app::FlatNamespacePtr& flat = startup_info_->flat_namespace;
  mx_status_t status = mxio_ns_create(&mxio_namespc);
  if (status != MX_OK) {
    FTL_LOG(ERROR) << "Failed to create namespace";
    return nullptr;
  }
  for (size_t i = 0; i < flat->paths.size(); ++i) {
    if (flat->paths[i] == kServiceRootPath) {
      // Ownership of /svc goes to the ApplicationContext created below.
      continue;
    }
    mx::channel dir = std::move(flat->directories[i]);
    mx_handle_t dir_handle = dir.release();
    const char* path = flat->paths[i].data();
    status = mxio_ns_bind(mxio_namespc, path, dir_handle);
    if (status != MX_OK) {
      FTL_LOG(ERROR) << "Failed to bind " << flat->paths[i] << " to namespace";
      mx_handle_close(dir_handle);
      mxio_ns_destroy(mxio_namespc);
      return nullptr;
    }
  }
  return mxio_namespc;
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
  mtl::MessageLoop::GetCurrent()->SetAfterTaskCallback(AfterTask);

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

  mxio_ns_t* mxio_namespc = SetupNamespace();
  if (mxio_namespc == nullptr)
    return false;

  InitBuiltinLibrariesForIsolate(
      url_, mxio_namespc,
      app::ApplicationContext::CreateFrom(std::move(startup_info_)),
      std::move(outgoing_services));

  Dart_Handle dart_arguments = Dart_NewList(arguments.size());
  if (Dart_IsError(dart_arguments)) {
    FTL_LOG(ERROR) << "Failed to allocate Dart arguments list";
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
    FTL_LOG(ERROR) << Dart_GetError(main);
    Dart_ExitScope();
    return false;
  }

  Dart_ExitScope();
  return true;
}

void DartApplicationController::Kill() {
  if (Dart_CurrentIsolate()) {
    mtl::MessageLoop::GetCurrent()->SetAfterTaskCallback(nullptr);
    tonic::DartMicrotaskQueue::GetForCurrentThread()->Destroy();

    mtl::MessageLoop::GetCurrent()->QuitNow();

    // TODO(rosswang): The docs warn of threading issues if doing this again,
    // but without this, attempting to shut down the isolate finalizes app
    // contexts that can't tell a shutdown is in progress and so fatal.
    Dart_SetMessageNotifyCallback(nullptr);

    Dart_ShutdownIsolate();
  }
}

void DartApplicationController::Detach() {
  binding_.set_connection_error_handler(ftl::Closure());
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

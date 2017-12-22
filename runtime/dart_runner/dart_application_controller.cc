// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/dart_application_controller.h"

#include <fcntl.h>
#include <zircon/status.h>
#include <fdio/namespace.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <utility>

#include "lib/app/cpp/application_context.h"
#include "topaz/runtime/dart_runner/builtin_libraries.h"
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
    fdio_ns_t* namespc,
    const uint8_t* isolate_snapshot_data,
    const uint8_t* isolate_snapshot_instructions,
#if !defined(AOT_RUNTIME)
    const uint8_t* script_snapshot,
    intptr_t script_snapshot_len,
#endif  // !defined(AOT_RUNTIE)
    app::ApplicationStartupInfoPtr startup_info,
    std::string url,
    fidl::InterfaceRequest<app::ApplicationController> controller)
    : namespace_(namespc),
      isolate_snapshot_data_(isolate_snapshot_data),
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

DartApplicationController::~DartApplicationController() {
  if (namespace_) {
    fdio_ns_destroy(namespace_);
    namespace_ = nullptr;
  }
}

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

#if defined(SCRIPT_RUNTIME)
  Dart_Handle status =
      Dart_SetLibraryTagHandler(tonic::DartState::HandleLibraryTag);
  if (Dart_IsError(status)) {
    FXL_LOG(ERROR) << "Dart_SetLibraryTagHandler failed";
    return false;
  }
#endif

  state->SetIsolate(isolate_);

  state->message_handler().Initialize(
      fsl::MessageLoop::GetCurrent()->task_runner());

  state->SetReturnCodeCallback([this](uint32_t return_code) {
    return_code_ = return_code;
  });

  return true;
}

bool DartApplicationController::Main() {
  Dart_EnterScope();

#if defined(AOT_RUNTIME)
  Dart_Handle root_library = Dart_RootLibrary();
#elif defined(SCRIPT_RUNTIME)
  Dart_Handle url = Dart_NewStringFromUTF8(
      reinterpret_cast<const uint8_t*>(url_.data()), url_.length());
  if (Dart_IsError(url)) {
    FXL_LOG(ERROR) << "Failed to make string for url: " << url_;
    Dart_ExitScope();
    return false;
  }
  // The script_snapshot_ field holds the text of the script when we are
  // in the script runner.
  Dart_Handle script =
      Dart_NewStringFromUTF8(script_snapshot_, script_snapshot_len_);
  if (Dart_IsError(script)) {
    FXL_LOG(ERROR) << "Failed to make string for script";
    Dart_ExitScope();
    return false;
  }
  Dart_Handle root_library = Dart_LoadScript(url, url, script, 0, 0);
  if (Dart_IsError(root_library)) {
    FXL_LOG(ERROR) << "Failed to load script: " << url_;
    Dart_ExitScope();
    return false;
  }
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

  InitBuiltinLibrariesForIsolate(
      url_, namespace_,
      app::ApplicationContext::CreateFrom(std::move(startup_info_)),
      std::move(outgoing_services));
  namespace_ = nullptr;

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

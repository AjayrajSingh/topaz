// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application_controller.h"

#include <magenta/status.h>
#include <utility>

#include "application/lib/app/application_context.h"
#include "apps/dart_content_handler/builtin_libraries.h"
#include "dart/runtime/bin/embedded_dart_io.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/ftl/synchronization/mutex.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/mx/mx_converter.h"

using tonic::ToDart;

namespace dart_content_handler {
namespace {

void RunMicrotasks() {
  tonic::DartMicrotaskQueue::GetForCurrentThread()->RunMicrotasks();
}

}  // namespace

DartApplicationController::DartApplicationController(
    const uint8_t* vm_snapshot_data,
    const uint8_t* vm_snapshot_instructions,
    const uint8_t* isolate_snapshot_data,
    const uint8_t* isolate_snapshot_instructions,
    std::vector<char> script_snapshot,
    app::ApplicationStartupInfoPtr startup_info,
    std::string url,
    fidl::InterfaceRequest<app::ApplicationController> controller)
    : vm_snapshot_data_(vm_snapshot_data),
      vm_snapshot_instructions_(vm_snapshot_instructions),
      isolate_snapshot_data_(isolate_snapshot_data),
      isolate_snapshot_instructions_(isolate_snapshot_instructions),
      script_snapshot_(std::move(script_snapshot)),
      startup_info_(std::move(startup_info)),
      url_(std::move(url)),
      binding_(this) {
  if (controller.is_pending()) {
    binding_.Bind(std::move(controller));
    binding_.set_connection_error_handler([this] { Kill(); });
  }

  InitDartVM();
}

DartApplicationController::~DartApplicationController() {}

const char* kDartVMArgs[] = {
// clang-format off
#if defined(AOT_RUNTIME)
    "--precompilation",
#else
    "--enable_mirrors=false",
#endif
    // clang-format on
};

std::once_flag vm_initialized_;

void DartApplicationController::InitDartVM() {
  // TODO(rmacnak): When AOT snapshots are refactored to generate the VM
  // snapshot separately, move VM initialization before receiving the first
  // bundle.
  std::call_once(vm_initialized_, [this]() {
    dart::bin::BootstrapDartIo();

    // TODO(abarth): Make checked mode configurable.
    FTL_CHECK(Dart_SetVMFlags(arraysize(kDartVMArgs), kDartVMArgs));

    Dart_InitializeParams params = {};
    params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
    params.vm_snapshot_data = vm_snapshot_data_;
    params.vm_snapshot_instructions = vm_snapshot_instructions_;
    char* error = Dart_Initialize(&params);
    if (error)
      FTL_LOG(FATAL) << "Dart_Initialize failed: " << error;
  });
}

bool DartApplicationController::CreateIsolate() {
  // Create the isolate from the snapshot.
  char* error = nullptr;

  auto state = new tonic::DartState();  // owned by Dart_CreateIsolate
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
  return true;
}

bool DartApplicationController::Main() {
  Dart_EnterScope();

#if defined(AOT_RUNTIME)
  Dart_Handle root_library = Dart_RootLibrary();
#else
  Dart_Handle root_library = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<uint8_t*>(script_snapshot_.data()),
      script_snapshot_.size());
#endif

  // TODO(jeffbrown): Decide what we should do with any startup handles.
  // eg. Redirect stdin, stdout, and stderr.

  tonic::DartMicrotaskQueue::StartForCurrentThread();
  mtl::MessageLoop::GetCurrent()->SetAfterTaskCallback(RunMicrotasks);

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
      url_, url_, app::ApplicationContext::CreateFrom(std::move(startup_info_)),
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

}  // namespace dart_content_handler

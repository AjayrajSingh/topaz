// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application_controller.h"

#include <utility>
#include <magenta/status.h>

#include "apps/dart_content_handler/builtin_libraries.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/mx/mx_converter.h"

using tonic::ToDart;

namespace dart_content_handler {

DartApplicationController::DartApplicationController(
    std::vector<char> snapshot,
    app::ApplicationStartupInfoPtr startup_info,
    fidl::InterfaceRequest<app::ApplicationController> controller)
    : snapshot_(std::move(snapshot)),
      startup_info_(std::move(startup_info)),
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
  auto state = new tonic::DartState();  // owned by Dart_CreateIsolate
  isolate_ = Dart_CreateIsolate(startup_info_->launch_info->url.get().c_str(),
                                "main", isolate_snapshot_buffer, nullptr,
                                nullptr, state, &error);
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
  const std::string& url = startup_info_->launch_info->url.get();

  Dart_EnterScope();

  script_ = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<uint8_t*>(snapshot_.data()), snapshot_.size());

  // TODO(jeffbrown): Decide what we should do with any startup handles.
  // eg. Redirect stdin, stdout, and stderr.

  InitBuiltinLibrariesForIsolate(
      url, url, std::move(startup_info_->environment),
      std::move(startup_info_->launch_info->services));

  const fidl::Array<fidl::String>& arguments =
      startup_info_->launch_info->arguments;
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
      Dart_Invoke(script_, ToDart("main"), arraysize(argv), argv);
  if (Dart_IsError(main)) {
    FTL_LOG(ERROR) << Dart_GetError(main);
    Dart_ExitScope();
    return false;
  }

  Dart_ExitScope();
  return true;
}

void DartApplicationController::Kill(const KillCallback& callback) {
  Kill();
  callback();
}

void DartApplicationController::Kill() {
  // TODO(rosswang): The docs warn of threading issues if doing this again, but
  // without this, attempting to shut down the isolate finalizes app contexts
  // that can't tell a shutdown is in progress and so fatal.
  Dart_SetMessageNotifyCallback(nullptr);

  Dart_ShutdownIsolate();
}

void DartApplicationController::Detach() {
  binding_.set_connection_error_handler(ftl::Closure());
}

}  // namespace dart_content_handler

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application_controller.h"

#include <utility>
#include <magenta/status.h>

#include "apps/dart_content_handler/builtin_libraries.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/mx/mx_converter.h"

using tonic::ToDart;

namespace dart_content_handler {

DartApplicationController::DartApplicationController(
    std::vector<char> snapshot,
    modular::ApplicationStartupInfoPtr startup_info,
    fidl::InterfaceRequest<modular::ApplicationController> controller)
    : snapshot_(std::move(snapshot)),
      startup_info_(std::move(startup_info)),
      binding_(this) {
  // TODO(abarth): We need to bind the application controller on another thread
  // because this thread uses a Dart run loop.
}

DartApplicationController::~DartApplicationController() {}

void DartApplicationController::Run() {
  // Create the isolate from the snapshot.
  const std::string& url = startup_info_->launch_info->url.get();
  char* error = nullptr;
  isolate_ = Dart_CreateIsolate(url.c_str(), "main", isolate_snapshot_buffer,
                                nullptr, nullptr, &error);
  if (!isolate_) {
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return;
  }

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
    return;
  }
  for (size_t i = 0; i < arguments.size(); i++) {
    tonic::LogIfError(
        Dart_ListSetAt(dart_arguments, i, ToDart(arguments[i].get())));
  }

  Dart_Handle argv[] = {
      dart_arguments,
  };
  tonic::LogIfError(Dart_Invoke(script_, Dart_NewStringFromCString("main"),
                                arraysize(argv), argv));

  Dart_ExitScope();

  Dart_EnterScope();
  tonic::LogIfError(Dart_RunLoop());
  Dart_ExitScope();

  Dart_ShutdownIsolate();
}

void DartApplicationController::Kill(const KillCallback& callback) {
  Dart_ShutdownIsolate();
  callback();
}

void DartApplicationController::Detach() {
  binding_.set_connection_error_handler(ftl::Closure());
}

}  // namespace dart_content_handler

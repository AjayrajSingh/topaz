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
    const std::string& url,
    fidl::Array<fidl::String> arguments,
    std::vector<char> snapshot,
    fidl::InterfaceHandle<modular::ApplicationEnvironment> environment,
    fidl::InterfaceRequest<modular::ServiceProvider> outgoing_services,
    fidl::InterfaceRequest<modular::ApplicationController> controller)
    : url_(url),
      arguments_(std::move(arguments)),
      snapshot_(std::move(snapshot)),
      environment_(std::move(environment)),
      outgoing_services_(std::move(outgoing_services)),
      binding_(this) {
  // TODO(abarth): We need to bind the application controller on another thread
  // because this thread uses a Dart run loop.
}

DartApplicationController::~DartApplicationController() {}

void DartApplicationController::Run() {
  // Create the isolate from the snapshot.
  char* error = nullptr;
  isolate_ = Dart_CreateIsolate(url_.c_str(), "main", isolate_snapshot_buffer,
                                nullptr, nullptr, &error);
  if (!isolate_) {
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return;
  }

  Dart_EnterScope();

  script_ = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<uint8_t*>(snapshot_.data()), snapshot_.size());

  InitBuiltinLibrariesForIsolate(url_, url_, std::move(environment_),
                                 std::move(outgoing_services_));

  Dart_Handle arguments = Dart_NewList(arguments_.size());
  if (Dart_IsError(arguments)) {
    FTL_LOG(ERROR) << "Failed to allocate Dart arguments list";
    return;
  }
  for (size_t i = 0; i < arguments_.size(); i++) {
    tonic::LogIfError(
        Dart_ListSetAt(arguments, i, ToDart(arguments_[i].To<std::string>())));
  }

  Dart_Handle argv[] = {
      arguments,
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

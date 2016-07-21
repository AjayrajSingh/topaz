// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application.h"

#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/logging.h"

namespace dart_content_handler {

DartApplication::DartApplication(
    mojo::InterfaceRequest<mojo::Application> application,
    mojo::URLResponsePtr response)
    : application_(std::move(application)), response_(std::move(response)) {}

DartApplication::~DartApplication() {}

void DartApplication::Run() {
  char* error = nullptr;
  Dart_Isolate isolate = Dart_CreateIsolate(
      response_->url.get().c_str(), "main", nullptr, nullptr, nullptr, &error);
  if (!isolate) {
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return;
  }

  Dart_EnterScope();
  // TODO(abarth): Extract the snapshot from |response_|.
  Dart_Handle library = Dart_LoadScriptFromSnapshot(nullptr, 0);
  // TODO(abarth): Pass the appropriate arguments to |main|.
  Dart_Invoke(library, Dart_NewStringFromCString("main"), 0, nullptr);
  Dart_ExitScope();

  Dart_RunLoop();

  Dart_ShutdownIsolate();
}

}  // namespace dart_content_handler

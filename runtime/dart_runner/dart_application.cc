// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application.h"

#include <utility>

#include "apps/dart_content_handler/builtin_libraries.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "apps/dart_content_handler/zip/unzipper.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/mtl/data_pipe/vector.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/mojo/mojo_converter.h"

using tonic::ToDart;

namespace dart_content_handler {
namespace {

constexpr char kSnapshotKey[] = "snapshot_blob.bin";

std::vector<char> ExtractSnapshot(std::vector<char> bundle) {
  zip::Unzipper unzipper(std::move(bundle));
  return unzipper.Extract(kSnapshotKey);
}

}  // namespace

DartApplication::DartApplication(
    mojo::InterfaceRequest<mojo::Application> application,
    mojo::URLResponsePtr response)
    : application_(std::move(application)), response_(std::move(response)) {}

DartApplication::~DartApplication() {}

void DartApplication::Run() {
  std::vector<char> bundle;

  bool result = mtl::BlockingCopyToVector(std::move(response_->body), &bundle);
  if (!result) {
    FTL_LOG(ERROR) << "Failed to receive bundle.";
    return;
  }

  std::vector<char> snapshot = ExtractSnapshot(std::move(bundle));
  std::string script_uri = response_->url.get();

  char* error = nullptr;
  Dart_Isolate isolate =
      Dart_CreateIsolate(script_uri.c_str(), "main", isolate_snapshot_buffer,
                         nullptr, nullptr, &error);
  if (!isolate) {
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return;
  }

  Dart_EnterScope();

  Dart_Handle library = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<uint8_t*>(snapshot.data()), snapshot.size());
  // TODO(abarth): Pass the appropriate arguments to |main|.

  InitBuiltinLibrariesForIsolate(script_uri, script_uri);

  Dart_Handle argv[2] = {
      Dart_NewList(0),
      ToDart(application_.PassMessagePipe().release().value())};

  tonic::LogIfError(Dart_Invoke(library, Dart_NewStringFromCString("main"),
                                arraysize(argv), argv));

  Dart_ExitScope();

  Dart_EnterScope();
  Dart_RunLoop();
  Dart_ExitScope();

  Dart_ShutdownIsolate();
}

}  // namespace dart_content_handler

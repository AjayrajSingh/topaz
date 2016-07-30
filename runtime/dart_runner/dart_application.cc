// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_application.h"

#include <utility>

#include "apps/dart_content_handler/zip/zip_archive.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/logging.h"
#include "lib/mtl/data_pipe/vector.h"

namespace dart_content_handler {
namespace {

constexpr char kSnapshotKey[] = "snapshot_blob.bin";

std::vector<char> ExtractSnapshot(std::vector<char> bundle) {
  ZipArchive archive(std::move(bundle));
  return archive.Extract(kSnapshotKey);
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

  char* error = nullptr;
  Dart_Isolate isolate = Dart_CreateIsolate(
      response_->url.get().c_str(), "main", nullptr, nullptr, nullptr, &error);
  if (!isolate) {
    FTL_LOG(ERROR) << "Dart_CreateIsolate failed: " << error;
    return;
  }

  Dart_EnterScope();
  Dart_Handle library = Dart_LoadScriptFromSnapshot(
      reinterpret_cast<uint8_t*>(snapshot.data()), snapshot.size());
  // TODO(abarth): Pass the appropriate arguments to |main|.
  Dart_Invoke(library, Dart_NewStringFromCString("main"), 0, nullptr);
  Dart_ExitScope();

  Dart_RunLoop();

  Dart_ShutdownIsolate();
}

}  // namespace dart_content_handler

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_init.h"

#include "apps/dart_content_handler/builtin_libraries.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "mojo/public/platform/dart/dart_handle_watcher.h"

namespace dart_content_handler {
namespace {

const char* kDartArgs[] = {
    "--enable_asserts",        "--enable_type_checks",   "--error_on_bad_type",
    "--error_on_bad_override", "--enable_mirrors=false",
};

}  // namespace

void InitDartVM() {
  SetHandleWatcherProducerHandle(mojo::dart::HandleWatcher::Start());

  // TODO(abarth): Make checked mode configurable.
  FTL_CHECK(Dart_SetVMFlags(arraysize(kDartArgs), kDartArgs));

  Dart_InitializeParams params = {};
  params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
  params.vm_isolate_snapshot = dart_content_handler::vm_isolate_snapshot_buffer;
  // TODO(abarth): Link in a VM snapshot.
  char* error = Dart_Initialize(&params);
  if (error)
    FTL_LOG(FATAL) << error;
}

}  // namespace dart_content_handler

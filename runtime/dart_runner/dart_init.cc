// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_init.h"

#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"

namespace dart_content_handler {
namespace {

const char* kDartArgs[] = {
    "--enable_asserts",        "--enable_type_checks",   "--error_on_bad_type",
    "--error_on_bad_override", "--enable_mirrors=false",
};

}  // namespace

void InitDartVM() {
  // TODO(abarth): Make checked mode configurable.
  FTL_CHECK(Dart_SetVMFlags(arraysize(kDartArgs), kDartArgs));

  // TODO(abarth): Link in a VM snapshot.
  char* error = Dart_Initialize(nullptr, nullptr, nullptr, nullptr, nullptr,
                                nullptr, nullptr, nullptr, nullptr, nullptr,
                                nullptr, nullptr, nullptr, nullptr);
  if (error)
    FTL_LOG(FATAL) << error;
}

}  // namespace dart_content_handler

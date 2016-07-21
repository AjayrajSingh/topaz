// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/dart_init.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/logging.h"

namespace dart_content_handler {

void InitDartVM() {
  char* error = Dart_Initialize(nullptr, nullptr, nullptr, nullptr, nullptr,
                                nullptr, nullptr, nullptr, nullptr, nullptr,
                                nullptr, nullptr, nullptr, nullptr);
  if (error)
    FTL_LOG(FATAL) << error;
}

}  // namespace dart_content_handler

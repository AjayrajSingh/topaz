// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/ftl/memory/unique_object.h"

namespace dart_content_handler {

struct UniqueZipArchiveTraits {
  static void* InvalidValue() { return nullptr; }
  static void Free(void* file);
};

using UniqueZipArchive = ftl::UniqueObject<void*, UniqueZipArchiveTraits>;

}  // namespace dart_content_handler

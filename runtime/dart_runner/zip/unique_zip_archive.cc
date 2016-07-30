// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/zip/unique_zip_archive.h"

#include "third_party/zlib/contrib/minizip/unzip.h"

namespace dart_content_handler {

void UniqueZipArchiveTraits::Free(void* file) {
  unzClose(file);
}

}  // namespace dart_content_handler

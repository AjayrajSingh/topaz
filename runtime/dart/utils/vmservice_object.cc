// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart/utils/vmservice_object.h"

#include <errno.h>
#include <zircon/status.h>

#include "src/lib/files/directory.h"
#include "src/lib/files/file.h"

#include <string>

namespace fuchsia {
namespace dart {

void VMServiceObject::GetContents(LazyEntryVector* out_vector) {
  // List /tmp/dart.services if it exists, and push its contents as
  // as the conrtents of this directory.
  std::vector<std::string> files;
  if (!files::ReadDirContents(kPortDir, &files)) {
    FXL_LOG(ERROR) << "Failed to read Dart VM Service port directory '"
                   << kPortDir << "':" << strerror(errno);
    return;
  }
  for (const auto& file : files) {
    if ((file == ".") || (file == "..")) {
      continue;
    }
    out_vector->push_back({std::stoul(file), file, V_TYPE_FILE});
  }
}

zx_status_t VMServiceObject::GetFile(fbl::RefPtr<fs::Vnode>* out, uint64_t id,
                                     fbl::String name) {
  return ZX_ERR_NOT_FOUND;
}

}  // namespace dart
}  // namespace fuchsia

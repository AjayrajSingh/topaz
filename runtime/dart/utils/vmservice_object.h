// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_UTILS_VMSERVICE_OBJECT_H_
#define TOPAZ_RUNTIME_DART_UTILS_VMSERVICE_OBJECT_H_

#include <fs/lazy-dir.h>

namespace fuchsia {
namespace dart {

class VMServiceObject : public fs::LazyDir {
 public:
  static constexpr const char* kDirName = "DartVM";
  static constexpr const char* kPortDirName = "vmservice-port";
  static constexpr const char* kPortDir = "/tmp/dart.services";

  void GetContents(LazyEntryVector* out_vector) override;
  zx_status_t GetFile(fbl::RefPtr<Vnode>* out, uint64_t id,
                      fbl::String name) override;
};

}  // namespace dart
}  // namespace fuchsia

#endif  // TOPAZ_RUNTIME_DART_UTILS_VMSERVICE_OBJECT_H_

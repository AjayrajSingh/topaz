// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "third_party/zlib/contrib/minizip/ioapi.h"

namespace zip {
namespace internal {

// An in-memory implementation of the zlib file interface. This implementation
// expects an std::vector<char> as the |opaque| field of the struct and ignores
// the filename and mode parameters.
extern const zlib_filefunc_def kMemoryIO;

}  // namespace internal
}  // namespace zip

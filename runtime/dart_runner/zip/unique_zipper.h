// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/ftl/memory/unique_object.h"

namespace zip {

struct UniqueZipperTraits {
  static inline void* InvalidValue() { return nullptr; }
  static inline bool IsValid(void* value) { return value != InvalidValue(); }
  static void Free(void* file);
};

using UniqueZipper = ftl::UniqueObject<void*, UniqueZipperTraits>;

}  // namespace zip

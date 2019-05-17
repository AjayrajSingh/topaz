// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_UTILS_INLINES_H_
#define TOPAZ_RUNTIME_DART_UTILS_INLINES_H_

#include <lib/syslog/global.h>

namespace dart_utils {

inline void Check(bool condition, const char* tag, const char* message = "") {
  if (!condition) {
    FX_LOG(FATAL, tag, message);
  }
}

#ifndef NDEBUG
#define DEBUG_CHECK(condition, tag, message) \
dart_utils::Check(condition, tag, message)
#else
#define DEBUG_CHECK(condition, tag, message) (true || (condition))
#endif

template<size_t SIZE, typename T>
inline size_t ArraySize(T (&array)[SIZE]) {
  return SIZE;
}

}  // namespace dart_utils

#endif  // TOPAZ_RUNTIME_DART_UTILS_INLINES_H_

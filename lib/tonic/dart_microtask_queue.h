// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_DART_MICROTASK_QUEUE_H_
#define LIB_TONIC_DART_MICROTASK_QUEUE_H_

#include "dart/runtime/include/dart_api.h"
#include "lib/tonic/logging/dart_error.h"

namespace tonic {

class DartMicrotaskQueue {
 public:
  static void ScheduleMicrotask(Dart_Handle callback);
  static void RunMicrotasks();
  static DartErrorHandleType GetLastError();
};

}  // namespace tonic

#endif  // LIB_TONIC_DART_MICROTASK_QUEUE_H_

// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_DART_CLASS_PROVIDER_H_
#define LIB_TONIC_DART_CLASS_PROVIDER_H_

#include "lib/ftl/macros.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/tonic/dart_persistent_value.h"

namespace tonic {
class DartState;

class DartClassProvider {
 public:
  DartClassProvider(DartState* dart_state, const char* library_name);
  ~DartClassProvider();

  Dart_Handle GetClassByName(const char* class_name);

 private:
  DartPersistentValue library_;

  FTL_DISALLOW_COPY_AND_ASSIGN(DartClassProvider);
};

}  // namespace tonic

#endif  // LIB_TONIC_DART_CLASS_PROVIDER_H_

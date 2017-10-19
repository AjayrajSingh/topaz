// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_SCOPES_DART_API_SCOPE_H_
#define LIB_TONIC_SCOPES_DART_API_SCOPE_H_

#include "lib/fxl/macros.h"
#include "third_party/dart/runtime/include/dart_api.h"

namespace tonic {

class DartApiScope {
 public:
  DartApiScope() { Dart_EnterScope(); }
  ~DartApiScope() {
    if (Dart_CurrentIsolate())
      Dart_ExitScope();
  }

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(DartApiScope);
};

}  // namespace tonic

#endif  // LIB_TONIC_SCOPES_DART_API_SCOPE_H_

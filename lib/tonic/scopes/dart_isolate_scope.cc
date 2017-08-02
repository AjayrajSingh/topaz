// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/scopes/dart_isolate_scope.h"

namespace tonic {

DartIsolateScope::DartIsolateScope(Dart_Isolate isolate) {
  isolate_ = isolate;
  previous_ = Dart_CurrentIsolate();
  if (previous_ == isolate_)
    return;
  if (previous_)
    Dart_ExitIsolate();
  Dart_EnterIsolate(isolate_);
}

DartIsolateScope::~DartIsolateScope() {
  Dart_Isolate current = Dart_CurrentIsolate();
  FTL_DCHECK(!current || current == isolate_);
  if (previous_ == isolate_)
    return;
  if (current)
    Dart_ExitIsolate();
  if (previous_)
    Dart_EnterIsolate(previous_);
}

}  // namespace tonic

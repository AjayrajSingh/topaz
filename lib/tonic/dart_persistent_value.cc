// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_persistent_value.h"

#include "lib/tonic/scopes/dart_isolate_scope.h"
#include "lib/tonic/dart_state.h"

namespace tonic {

DartPersistentValue::DartPersistentValue() : value_(nullptr) {}

DartPersistentValue::DartPersistentValue(DartPersistentValue&& other)
    : dart_state_(other.dart_state_), value_(other.value_) {
  other.dart_state_ = ftl::WeakPtr<DartState>();
  other.value_ = nullptr;
}

DartPersistentValue::DartPersistentValue(DartState* dart_state,
                                         Dart_Handle value)
    : value_(nullptr) {
  Set(dart_state, value);
}

DartPersistentValue::~DartPersistentValue() {
  Clear();
}

void DartPersistentValue::Set(DartState* dart_state, Dart_Handle value) {
  FTL_DCHECK(is_empty());
  dart_state_ = dart_state->GetWeakPtr();
  value_ = Dart_NewPersistentHandle(value);
}

void DartPersistentValue::Clear() {
  if (!value_ || !dart_state_.get())
    return;

  DartIsolateScope scope(dart_state_->isolate());
  Dart_DeletePersistentHandle(value_);
  dart_state_ = ftl::WeakPtr<DartState>();
  value_ = nullptr;
}

Dart_Handle DartPersistentValue::Release() {
  if (!value_)
    return nullptr;
  Dart_Handle local = Dart_HandleFromPersistent(value_);
  Clear();
  return local;
}
}

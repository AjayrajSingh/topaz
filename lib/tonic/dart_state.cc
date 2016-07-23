// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_state.h"

#include "lib/tonic/dart_class_library.h"
#include "lib/tonic/dart_converter.h"
#include "lib/tonic/dart_exception_factory.h"
#include "lib/tonic/dart_message_handler.h"

namespace tonic {

DartState::Scope::Scope(DartState* dart_state)
    : scope_(dart_state->isolate()) {}

DartState::Scope::~Scope() {}

DartState::DartState()
    : isolate_(nullptr),
      class_library_(std::unique_ptr<DartClassLibrary>(new DartClassLibrary)),
      exception_factory_(new DartExceptionFactory(this)),
      message_handler_(
          std::unique_ptr<DartMessageHandler>(new DartMessageHandler())),
      weak_factory_(this) {}

DartState::~DartState() {}

void DartState::SetIsolate(Dart_Isolate isolate) {
  isolate_ = isolate;
  if (!isolate_)
    return;

  {
    Scope dart_scope(this);
    index_handle_.Set(this, ToDart("index"));
  }

  DidSetIsolate();
}

DartState* DartState::From(Dart_Isolate isolate) {
  return static_cast<DartState*>(Dart_IsolateData(isolate));
}

DartState* DartState::Current() {
  return static_cast<DartState*>(Dart_CurrentIsolateData());
}

ftl::WeakPtr<DartState> DartState::GetWeakPtr() {
  return weak_factory_.GetWeakPtr();
}

}  // namespace tonic

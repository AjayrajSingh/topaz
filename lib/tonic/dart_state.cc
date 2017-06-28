// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_state.h"

#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_class_library.h"
#include "lib/tonic/dart_message_handler.h"
#include "lib/tonic/file_loader/file_loader.h"

#ifdef OS_FUCHSIA
#include "lib/tonic/handle_table.h"
#endif

namespace tonic {

DartState::Scope::Scope(DartState* dart_state)
    : scope_(dart_state->isolate()) {}

DartState::Scope::~Scope() {}

DartState::DartState()
    : isolate_(nullptr),
      class_library_(new DartClassLibrary),
      message_handler_(new DartMessageHandler()),
      file_loader_(new FileLoader()),
#ifdef OS_FUCHSIA
      handle_table_(new HandleTable()),
#endif
      weak_factory_(this) {}

DartState::~DartState() {}

void DartState::SetIsolate(Dart_Isolate isolate) {
  isolate_ = isolate;
  if (!isolate_)
    return;
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

void DartState::DidSetIsolate() {}

Dart_Handle DartState::HandleLibraryTag(Dart_LibraryTag tag,
                                        Dart_Handle library,
                                        Dart_Handle url) {
  return Current()->file_loader().HandleLibraryTag(tag, library, url);
}

}  // namespace tonic

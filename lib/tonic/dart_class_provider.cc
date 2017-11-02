// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_class_provider.h"

#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/dart_state.h"

namespace tonic {

DartClassProvider::DartClassProvider(DartState* dart_state,
                                     const char* class_name) {
  library_.Set(dart_state, Dart_LookupLibrary(ToDart(class_name)));
}

DartClassProvider::~DartClassProvider() {}

Dart_Handle DartClassProvider::GetClassByName(const char* class_name) {
  Dart_Handle name_handle = ToDart(class_name);
  Dart_Handle class_handle =
      Dart_GetType(library_.value(), name_handle, 0, nullptr);
  FXL_DCHECK(!Dart_IsError(class_handle)) << class_name << ": "
                                          << Dart_GetError(class_handle);
  return class_handle;
}

}  // namespace tonic

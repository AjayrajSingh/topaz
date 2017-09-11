// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_list.h"

#include "lib/tonic/logging/dart_error.h"

namespace tonic {

DartList::DartList(Dart_Handle dart_handle) : dart_handle_(dart_handle) {
  FXL_DCHECK(Dart_IsList(dart_handle_));

  intptr_t length;
  is_valid_ = !LogIfError(Dart_ListLength(dart_handle_, &length));
  size_ = length;
}

DartList::DartList() {
  dart_handle_ = Dart_Null();
  size_ = 0;
  is_valid_ = false;
}

DartList::DartList(DartList&& other)
    : dart_handle_(other.dart_handle_),
      size_(other.size_),
      is_valid_(other.is_valid_) {
  other.dart_handle_ = nullptr;
  other.size_ = 0;
  other.is_valid_ = false;
}

void DartList::Set(size_t index, Dart_Handle value) {
  LogIfError(Dart_ListSetAt(dart_handle_, index, value));
}

DartList DartConverter<DartList>::FromArguments(Dart_NativeArguments args,
                                                int index,
                                                Dart_Handle& exception) {
  Dart_Handle list = Dart_GetNativeArgument(args, index);
  if (LogIfError(list) || !Dart_IsList(list)) {
    exception = Dart_NewApiError("Invalid Argument");
    return DartList();
  }

  return DartList(list);
}

}  // namespace tonic

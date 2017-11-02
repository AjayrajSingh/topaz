// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/typed_data/int32_list.h"

#include "lib/tonic/logging/dart_error.h"

namespace tonic {

Int32List::Int32List()
    : data_(nullptr), num_elements_(0), dart_handle_(nullptr) {}

Int32List::Int32List(Dart_Handle list)
    : data_(nullptr), num_elements_(0), dart_handle_(list) {
  if (Dart_IsNull(list))
    return;

  Dart_TypedData_Type type;
  Dart_TypedDataAcquireData(list, &type, reinterpret_cast<void**>(&data_),
                            &num_elements_);
  FXL_DCHECK(!LogIfError(list));
  if (type != Dart_TypedData_kInt32)
    Dart_ThrowException(ToDart("Non-genuine Int32List passed to engine."));
}

Int32List::Int32List(Int32List&& other)
    : data_(other.data_),
      num_elements_(other.num_elements_),
      dart_handle_(other.dart_handle_) {
  other.data_ = nullptr;
  other.dart_handle_ = nullptr;
}

Int32List::~Int32List() {
  Release();
}

void Int32List::Release() {
  if (data_) {
    Dart_TypedDataReleaseData(dart_handle_);
    data_ = nullptr;
    num_elements_ = 0;
    dart_handle_ = nullptr;
  }
}

Int32List DartConverter<Int32List>::FromArguments(Dart_NativeArguments args,
                                                  int index,
                                                  Dart_Handle& exception) {
  Dart_Handle list = Dart_GetNativeArgument(args, index);
  FXL_DCHECK(!LogIfError(list));
  return Int32List(list);
}

void DartConverter<Int32List>::SetReturnValue(Dart_NativeArguments args,
                                              Int32List val) {
  Dart_SetReturnValue(args, val.dart_handle());
}

}  // namespace tonic

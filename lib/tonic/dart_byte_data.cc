// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_byte_data.h"

#include "lib/tonic/dart_error.h"

namespace tonic {

DartByteData::DartByteData()
    : data_(nullptr), length_in_bytes_(0), dart_handle_(nullptr) {}

DartByteData::DartByteData(Dart_Handle list)
    : data_(nullptr), length_in_bytes_(0), dart_handle_(list) {
  if (Dart_IsNull(list))
    return;

  Dart_TypedData_Type type;
  Dart_TypedDataAcquireData(list, &type, &data_, &length_in_bytes_);
  FTL_DCHECK(!LogIfError(list));
  FTL_DCHECK(type == Dart_TypedData_kByteData);
}

DartByteData::DartByteData(DartByteData&& other)
    : data_(other.data_),
      length_in_bytes_(other.length_in_bytes_),
      dart_handle_(other.dart_handle_) {
  other.data_ = nullptr;
  other.dart_handle_ = nullptr;
}

DartByteData::~DartByteData() {
  Release();
}

std::vector<char> DartByteData::Copy() const {
  const char* ptr = static_cast<const char*>(data_);
  return std::vector<char>(ptr, ptr + length_in_bytes_);
}

void DartByteData::Release() const {
  if (data_) {
    Dart_TypedDataReleaseData(dart_handle_);
    data_ = nullptr;
  }
}

DartByteData DartConverter<DartByteData>::FromArguments(
    Dart_NativeArguments args,
    int index,
    Dart_Handle& exception) {
  Dart_Handle data = Dart_GetNativeArgument(args, index);
  FTL_DCHECK(!LogIfError(data));
  return DartByteData(data);
}

void DartConverter<DartByteData>::SetReturnValue(Dart_NativeArguments args,
                                                 DartByteData val) {
  Dart_SetReturnValue(args, val.dart_handle());
}

}  // namespace tonic

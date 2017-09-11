// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_TYPED_DATA_FLOAT64_LIST_H_
#define LIB_TONIC_TYPED_DATA_FLOAT64_LIST_H_

#include "dart/runtime/include/dart_api.h"
#include "lib/tonic/converter/dart_converter.h"

namespace tonic {

// A simple wrapper around a Dart Float64List. It uses Dart_TypedDataAcquireData
// to obtain a raw pointer to the data, which is released when this object is
// destroyed.
//
// This is designed to be used with DartConverter only.
class Float64List {
 public:
  explicit Float64List(Dart_Handle list);
  Float64List(Float64List&& other);
  Float64List();
  ~Float64List();

  double& at(intptr_t i) {
    FXL_CHECK(i < num_elements_);
    return data_[i];
  }
  const double& at(intptr_t i) const {
    FXL_CHECK(i < num_elements_);
    return data_[i];
  }

  double& operator[](intptr_t i) { return at(i); }
  const double& operator[](intptr_t i) const { return at(i); }

  const double* data() const { return data_; }
  intptr_t num_elements() const { return num_elements_; }
  Dart_Handle dart_handle() const { return dart_handle_; }

  void Release();

 private:
  double* data_;
  intptr_t num_elements_;
  Dart_Handle dart_handle_;

  Float64List(const Float64List& other) = delete;
};

template <>
struct DartConverter<Float64List> {
  static void SetReturnValue(Dart_NativeArguments args, Float64List val);
  static Float64List FromArguments(Dart_NativeArguments args,
                                   int index,
                                   Dart_Handle& exception);
};

}  // namespace tonic

#endif  // LIB_TONIC_TYPED_DATA_FLOAT64_LIST_H_

// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_MX_CONVERTER_H_
#define LIB_TONIC_MX_CONVERTER_H_

#include <mx/handle.h>

#include "lib/tonic/converter/dart_converter.h"

namespace tonic {

template <typename HandleType>
struct DartConverter<HandleType, typename std::enable_if<std::is_base_of<mx::handle<HandleType>, HandleType>::value>::type> {
  static HandleType FromDart(Dart_Handle handle) {
    uint64_t raw_handle = 0;
    Dart_Handle result = Dart_IntegerToUint64(handle, &raw_handle);
    if (Dart_IsError(result) || !raw_handle)
      return HandleType();

    return HandleType(static_cast<mx_handle_t>(raw_handle));
  }

  static Dart_Handle ToDart(HandleType mx_handle) {
    return Dart_NewInteger(static_cast<int64_t>(mx_handle.release()));
  }

  static HandleType
  FromArguments(Dart_NativeArguments args, int index, Dart_Handle& exception) {
    int64_t raw_handle = 0;
    Dart_Handle result =
        Dart_GetNativeIntegerArgument(args, index, &raw_handle);
    if (Dart_IsError(result) || !raw_handle)
      return HandleType();

    return HandleType(static_cast<mx_handle_t>(raw_handle));
  }
};

}  // namespace tonic

#endif  // LIB_TONIC_MX_CONVERTER_H_

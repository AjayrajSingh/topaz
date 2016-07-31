// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_FILE_LOADER_STRING_CONVERTER_H_
#define LIB_TONIC_FILE_LOADER_STRING_CONVERTER_H_

#include <string>

#include "dart/runtime/include/dart_api.h"

namespace tonic {

// Redundant with StdStringFromDart but better than adding a dependency on the
// rest of tonic.
std::string StringFromDart(Dart_Handle string);

// Redundant with StdStringToDart but better than adding a dependency on the
// rest of tonic.
Dart_Handle StringToDart(const std::string& string);

}  // namespace tonic

#endif  // LIB_TONIC_FILE_LOADER_STRING_CONVERTER_H_

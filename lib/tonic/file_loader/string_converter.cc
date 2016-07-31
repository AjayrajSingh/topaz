// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/file_loader/string_converter.h"

#include "lib/ftl/logging.h"

namespace tonic {

std::string StringFromDart(Dart_Handle string) {
  FTL_CHECK(Dart_IsString(string));
  uint8_t* utf8_array = nullptr;
  intptr_t length = 0;
  Dart_StringToUTF8(string, &utf8_array, &length);
  return std::string(reinterpret_cast<const char*>(utf8_array), length);
}

Dart_Handle StringToDart(const std::string& string) {
  return Dart_NewStringFromUTF8(reinterpret_cast<const uint8_t*>(string.data()),
                                string.length());
}

}  // namespace tonic

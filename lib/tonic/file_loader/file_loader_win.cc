// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/file_loader/file_loader.h"

#include <iostream>
#include <memory>
#include <utility>

#include "lib/fxl/files/directory.h"
#include "lib/fxl/files/file.h"
#include "lib/fxl/files/path.h"
#include "lib/fxl/files/symlink.h"
#include "lib/fxl/logging.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/parsers/packages_map.h"

namespace tonic {
namespace {

void FindAndReplaceInPlace(std::string& str,
                           const std::string& findStr,
                           const std::string& replaceStr) {
  size_t pos = 0;
  while ((pos = str.find(findStr, pos)) != std::string::npos) {
    str.replace(pos, findStr.length(), replaceStr);
    pos += replaceStr.length();
  }
}

} // namespace

const char FileLoader::kFileURLPrefix[] = "file:///";
const size_t FileLoader::kFileURLPrefixLength = sizeof(FileLoader::kFileURLPrefix) - 1;
const std::string FileLoader::kPathSeparator = "\\";

std::string FileLoader::SanitizePath(const std::string& url) {
  std::string sanitized = url;
  FindAndReplaceInPlace(sanitized, "/", FileLoader::kPathSeparator);
  return SanitizeURIEscapedCharacters(sanitized);
}

std::string FileLoader::CanonicalizeFileURL(const std::string& url) {
  return SanitizePath(url.substr(FileLoader::kFileURLPrefixLength));
}

bool FileLoader::ReadFileToString(const std::string& path,
                                  std::string* result) {
  FXL_DCHECK(dirfd_ == -1);
  return files::ReadFileToString(path, result);
}

std::pair<uint8_t*, intptr_t> FileLoader::ReadFileToBytes(const std::string& path) {
  FXL_DCHECK(dirfd_ == -1);
  return files::ReadFileToBytes(path);
}

}  // namespace tonic

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/file_loader/file_loader.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>

#include <iostream>
#include <memory>
#include <utility>

#include "lib/fxl/files/directory.h"
#include "lib/fxl/files/file.h"
#include "lib/fxl/files/path.h"
#include "lib/fxl/files/symlink.h"
#include "lib/fxl/files/unique_fd.h"
#include "lib/fxl/logging.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/parsers/packages_map.h"

namespace tonic {

const std::string FileLoader::kPathSeparator = "/";
const char FileLoader::kFileURLPrefix[] = "file://";
const size_t FileLoader::kFileURLPrefixLength = sizeof(FileLoader::kFileURLPrefix) - 1;

namespace {

const size_t kFileSchemeLength = FileLoader::kFileURLPrefixLength - 2;

}  // namespace

std::string FileLoader::SanitizePath(const std::string& url) {
  std::string sanitized = url;
  SanitizeURIEscapedCharactersInPlace(sanitized);
  return sanitized;
}

std::string FileLoader::CanonicalizeFileURL(const std::string& url) {
  return url.substr(kFileSchemeLength);
}

bool FileLoader::ReadFileToString(const std::string& path,
                                  std::string* result) {
  if (dirfd_ == -1)
    return files::ReadFileToString(path, result);
  const char* cpath = path.c_str();
  const int offset = (cpath[0] == '/') ? 1 : 0;
  fxl::UniqueFD fd(openat(dirfd_, &cpath[offset], O_RDONLY));
  return files::ReadFileDescriptorToString(fd.get(), result);
}

std::pair<uint8_t*, intptr_t> FileLoader::ReadFileToBytes(const std::string& path) {
  if (dirfd_ == -1)
    return files::ReadFileToBytes(path);
  const char* cpath = path.c_str();
  const int offset = (cpath[0] == '/') ? 1 : 0;
  fxl::UniqueFD fd(openat(dirfd_, &cpath[offset], O_RDONLY));
  return files::ReadFileDescriptorToBytes(fd.get());
}

}  // namespace tonic

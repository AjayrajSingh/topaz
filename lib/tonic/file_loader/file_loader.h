// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_FILE_LOADER_FILE_LOADER_H_
#define LIB_TONIC_FILE_LOADER_FILE_LOADER_H_

#include <memory>
#include <set>
#include <string>

#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/macros.h"
#include "lib/tonic/parsers/packages_map.h"

namespace tonic {

class FileLoader {
 public:
  FileLoader();
  ~FileLoader();

  bool LoadPackagesMap(const std::string& packages);

  const std::set<std::string>& dependencies() const { return dependencies_; }

  Dart_Handle CanonicalizeURL(Dart_Handle library, Dart_Handle url);
  Dart_Handle Import(Dart_Handle url);
  Dart_Handle Source(Dart_Handle library, Dart_Handle url);

  std::string Fetch(const std::string& url);

 private:
  std::string GetFilePathForURL(std::string url);
  std::string GetFilePathForPackageURL(std::string url);
  std::string GetFilePathForFileURL(std::string url);

  std::set<std::string> dependencies_;
  std::string packages_;
  std::unique_ptr<PackagesMap> packages_map_;

  FTL_DISALLOW_COPY_AND_ASSIGN(FileLoader);
};

}  // namespace tonic

#endif  // LIB_TONIC_FILE_LOADER_FILE_LOADER_H_

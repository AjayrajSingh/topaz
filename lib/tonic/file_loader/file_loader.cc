// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/file_loader/file_loader.h"

#include <iostream>
#include <memory>
#include <utility>

#include "lib/ftl/files/directory.h"
#include "lib/ftl/files/file.h"
#include "lib/ftl/files/path.h"
#include "lib/ftl/files/symlink.h"
#include "lib/ftl/logging.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/parsers/packages_map.h"

namespace tonic {
namespace {

constexpr char kPackageScheme[] = "package:";
constexpr size_t kPackageSchemeLength = sizeof(kPackageScheme) - 1;

constexpr char kFileScheme[] = "file:";
constexpr size_t kFileSchemeLength = sizeof(kFileScheme) - 1;

constexpr char kFileURLPrefix[] = "file://";
constexpr size_t kFileURLPrefixLength = sizeof(kFileURLPrefix) - 1;

constexpr char kDartScheme[] = "dart:";

// Extract the scheme prefix ('package:' or 'file:' from )
std::string ExtractSchemePrefix(std::string url) {
  if (url.find(kPackageScheme) == 0u)
    return kPackageScheme;
  if (url.find(kFileScheme) == 0u)
    return kFileScheme;
  return std::string();
}

// Extract the path from a package: or file: url.
std::string ExtractPath(std::string url) {
  if (url.find(kPackageScheme) == 0u)
    return url.substr(kPackageSchemeLength);
  if (url.find(kFileScheme) == 0u)
    return url.substr(kFileSchemeLength);
  return url;
}

}  // namespace

FileLoader::FileLoader() {}

FileLoader::~FileLoader() {}

bool FileLoader::LoadPackagesMap(const std::string& packages) {
  packages_ = packages;
  dependencies_.insert(packages_);
  std::string packages_source;
  if (!files::ReadFileToString(packages_, &packages_source)) {
    std::cerr << "error: Unable to load .packages file '" << packages_ << "'."
              << std::endl;
    return false;
  }
  packages_map_.reset(new PackagesMap());
  std::string error;
  if (!packages_map_->Parse(packages_source, &error)) {
    std::cerr << "error: Unable to parse .packages file '" << packages_ << "'."
              << std::endl
              << error << std::endl;
    return false;
  }
  return true;
}

Dart_Handle FileLoader::CanonicalizeURL(Dart_Handle library, Dart_Handle url) {
  std::string string = StdStringFromDart(url);
  if (string.find(kDartScheme) == 0u)
    return url;
  if (string.find(kPackageScheme) == 0u)
    return url;
  if (string.find(kFileScheme) == 0u)
    return StdStringToDart(string.substr(kFileSchemeLength));

  std::string library_url = StdStringFromDart(Dart_LibraryUrl(library));
  std::string prefix = ExtractSchemePrefix(library_url);
  std::string base_path = ExtractPath(library_url);
  std::string simplified_path =
      files::SimplifyPath(files::GetDirectoryName(base_path) + "/" + string);
  return StdStringToDart(prefix + simplified_path);
}

std::string FileLoader::GetFilePathForURL(std::string url) {
  if (url.find(kPackageScheme) == 0u)
    return GetFilePathForPackageURL(std::move(url));
  if (url.find(kFileScheme) == 0u)
    return GetFilePathForFileURL(std::move(url));
  return url;
}

std::string FileLoader::GetFilePathForPackageURL(std::string url) {
  FTL_DCHECK(url.find(kPackageScheme) == 0u);
  url = url.substr(kPackageSchemeLength);
  size_t slash = url.find('/');
  if (slash == std::string::npos)
    return std::string();
  std::string package = url.substr(0, slash);
  std::string library_path = url.substr(slash + 1);
  std::string package_path = packages_map_->Resolve(package);
  if (package_path.empty())
    return std::string();
  if (package_path.find(kFileURLPrefix) == 0u)
    return package_path.substr(kFileURLPrefixLength) + library_path;
  return files::GetDirectoryName(packages_) + "/" + package_path + "/" +
         library_path;
}

std::string FileLoader::GetFilePathForFileURL(std::string url) {
  FTL_DCHECK(url.find(kFileURLPrefix) == 0u);
  return url.substr(kFileURLPrefixLength);
}

std::string FileLoader::Fetch(const std::string& url) {
  std::string path = GetFilePathForURL(url);
  std::string source;
  if (!files::ReadFileToString(files::GetAbsoluteFilePath(path), &source)) {
    std::cerr << "error: Unable to find Dart library '" << url << "'."
              << std::endl;
    exit(1);
  }
  dependencies_.insert(path);
  return source;
}

Dart_Handle FileLoader::Import(Dart_Handle url) {
  Dart_Handle source = StdStringToDart(Fetch(StdStringFromDart(url)));
  Dart_Handle result = Dart_LoadLibrary(url, Dart_Null(), source, 0, 0);
  DART_CHECK_VALID(result);
  return result;
}

Dart_Handle FileLoader::Source(Dart_Handle library, Dart_Handle url) {
  Dart_Handle source = StdStringToDart(Fetch(StdStringFromDart(url)));
  Dart_Handle result = Dart_LoadSource(library, url, Dart_Null(), source, 0, 0);
  DART_CHECK_VALID(result);
  return result;
}

}  // namespace tonic

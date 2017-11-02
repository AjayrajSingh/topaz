// Copyright 2016 The Fuchsia Authors. All rights reserved.
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

Dart_Handle FileLoader::HandleLibraryTag(Dart_LibraryTag tag,
                                         Dart_Handle library,
                                         Dart_Handle url) {
  FXL_DCHECK(Dart_IsNull(library) ||
             Dart_IsLibrary(library) ||
             Dart_IsString(library));
  FXL_DCHECK(Dart_IsString(url));
  if (tag == Dart_kCanonicalizeUrl)
    return CanonicalizeURL(library, url);
  if (tag == Dart_kImportTag)
    return Import(url);
  if (tag == Dart_kSourceTag)
    return Source(library, url);
  if (tag == Dart_kScriptTag) {
    // Clear dependencies.
    dependencies_.clear();
    url_dependencies_.clear();
    // Reload packages map.
    SetPackagesUrl(library);
    // Load the root script.
    return Script(url);
  }
  if (tag == Dart_kKernelTag)
    return Kernel(url);
  return Dart_NewApiError("Unknown library tag.");
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
  if (!packages_map_)
    return std::string();
  FXL_DCHECK(url.find(kPackageScheme) == 0u);
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
  return files::GetDirectoryName(files::AbsolutePath(packages_)) + "/" +
         package_path + "/" + library_path;
}

std::string FileLoader::GetFilePathForFileURL(std::string url) {
  FXL_DCHECK(url.find(kFileURLPrefix) == 0u);
  return url.substr(kFileURLPrefixLength);
}

std::string FileLoader::GetFileURLForPath(const std::string& path) {
  return std::string(kFileURLPrefix) + path;
}

std::string FileLoader::Fetch(const std::string& url,
                              std::string* resolved_url) {
  std::string path = files::SimplifyPath(GetFilePathForURL(url));
  if (resolved_url)
    *resolved_url = GetFileURLForPath(path);
  std::string source;
  if (!files::ReadFileToString(files::GetAbsoluteFilePath(path), &source)) {
    // TODO(johnmccutchan): The file loader should not explicitly log the error
    // or exit the process. Instead these errors should be reported to the
    // caller of the FileLoader who can implement the application-specific error
    // handling policy.
    std::cerr << "error: Unable to read Dart source '" << url << "'."
              << std::endl;
    exit(1);
  }
  url_dependencies_.insert(url);
  dependencies_.insert(path);
  return source;
}

std::pair<uint8_t*, intptr_t> FileLoader::FetchBytes(const std::string& url) {
  std::string path = files::SimplifyPath(GetFilePathForURL(url));
  auto result = files::ReadFileToBytes(files::GetAbsoluteFilePath(path));
  if (result.first == nullptr) {
    // TODO(aam): Same as above the file loader should not explicitly log the error
    // or exit the process. Instead these errors should be reported to the
    // caller of the FileLoader who can implement the application-specific error
    // handling policy.
    std::cerr << "error: Unable to read Dart source '" << url << "'."
              << std::endl;
    exit(1);
  }
  url_dependencies_.insert(url);
  dependencies_.insert(path);
  return result;
}

Dart_Handle FileLoader::LoadLibrary(const std::string& url) {
  std::string resolved_url;
  Dart_Handle source = ToDart(Fetch(url, &resolved_url));
  return Dart_LoadLibrary(ToDart(url), ToDart(resolved_url), source, 0, 0);
}

Dart_Handle FileLoader::LoadScript(const std::string& url) {
  std::string resolved_url;
  Dart_Handle source = ToDart(Fetch(url, &resolved_url));
  Dart_Handle result =
      Dart_LoadScript(ToDart(url), ToDart(resolved_url), source, 0, 0);
  if (!Dart_IsError(result)) {
    Dart_Handle finalize_result = Dart_FinalizeLoading(true);
    if (Dart_IsError(finalize_result))
      return finalize_result;
  }
  return result;
}

Dart_Handle FileLoader::Import(Dart_Handle url) {
  return LoadLibrary(StdStringFromDart(url));
}

namespace {
void ReleaseFetchedBytes(uint8_t* buffer) {
  free(buffer);
}
}

Dart_Handle FileLoader::Kernel(Dart_Handle url) {
  std::string url_string = StdStringFromDart(url);
  std::pair<uint8_t*, intptr_t> fetched_result = FetchBytes(url_string);
  // TODO(aam): With dartbug.com/28057 addressed, there should be no need
  // to pass ownership of fetched program through Dart_ReadKernelBinary.
  void* kernel_program = Dart_ReadKernelBinary(
      fetched_result.first,
      fetched_result.second,
      ReleaseFetchedBytes
  );
  if (kernel_program == NULL) {
    return Dart_NewApiError("Failed to read kernel binary");
  }
  return Dart_NewExternalTypedData(Dart_TypedData_kUint64, kernel_program, 1);
}

Dart_Handle FileLoader::Source(Dart_Handle library, Dart_Handle url) {
  std::string resolved_url;
  Dart_Handle source = ToDart(Fetch(StdStringFromDart(url), &resolved_url));
  return Dart_LoadSource(library, url, ToDart(resolved_url), source, 0, 0);
}

// This is invoked upon a reload request.
Dart_Handle FileLoader::Script(Dart_Handle url) {
  return LoadScript(StdStringFromDart(url));
}

void FileLoader::SetPackagesUrl(Dart_Handle url) {
  if (url == Dart_Null()) {
    // No packages url specified.
    LoadPackagesMap(packages());
    return;
  }
  const std::string& packages_url = StdStringFromDart(url);
  LoadPackagesMap(packages_url);
}

}  // namespace tonic

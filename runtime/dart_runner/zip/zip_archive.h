// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <string>
#include <vector>

#include "apps/dart_content_handler/zip/unique_zip_archive.h"
#include "lib/ftl/macros.h"

namespace dart_content_handler {

class ZipArchive {
 public:
  explicit ZipArchive(std::vector<char> buffer);
  ~ZipArchive();

  std::vector<char> Extract(const std::string& path);

  const std::vector<char>& buffer() const { return buffer_; }

 private:
  std::vector<char> buffer_;
  UniqueZipArchive archive_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ZipArchive);
};

}  // namespace dart_content_handler

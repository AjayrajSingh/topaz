// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <string>
#include <vector>

#include "apps/dart_content_handler/zip/unique_zipper.h"
#include "lib/ftl/macros.h"

namespace zip {

class Zipper {
 public:
  Zipper();
  ~Zipper();

  bool AddCompressedFile(const std::string& path,
                         const char* data,
                         size_t size);

  std::vector<char> Finish();

 private:
  std::vector<char> buffer_;
  UniqueZipper encoder_;

  FTL_DISALLOW_COPY_AND_ASSIGN(Zipper);
};

}  // namespace zip

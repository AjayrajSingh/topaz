// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_RUNNER_MAPPED_RESOURCE_H_
#define APPS_DART_RUNNER_MAPPED_RESOURCE_H_

#include <fdio/namespace.h>

#include "lib/fsl/vmo/sized_vmo.h"
#include "lib/fxl/macros.h"

namespace dart_runner {

class MappedResource {
 public:
  MappedResource() : address_(nullptr), size_(0) {}
  ~MappedResource();

  // Loads the content of a file from the given namespace and maps it into the
  // current process's address space. If namespace is null, the fdio "global"
  // namespace is used (in which case, ./pkg means the dart_runner's package).
  // The content is unmapped when the MappedResource goes out of scope. Returns
  // true on success.
  static bool LoadFromNamespace(fdio_ns_t* namespc, const std::string& path,
                                MappedResource& resource);

  // Maps a VMO into the current process's address space. The content is
  // unmapped when the MappedResource goes out of scope. Returns true on
  // success. The path is used only for error messages.
  static bool LoadFromVmo(const std::string& path, fsl::SizedVmo resource_vmo,
                          MappedResource& resource);

  void* address() { return address_; }
  size_t size() { return size_; }

 private:
  void* address_;
  size_t size_;

  FXL_DISALLOW_COPY_AND_ASSIGN(MappedResource);
};

}  // namespace dart_runner

#endif  // APPS_DART_RUNNER_MAPPED_RESOURCE_H_

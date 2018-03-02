// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/mapped_resource.h"

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <trace/event.h>
#include <zircon/status.h>

#include "lib/fsl/vmo/file.h"
#include "lib/fxl/logging.h"

namespace dart_content_handler {

bool MappedResource::LoadFromNamespace(fdio_ns_t* namespc,
                                       const std::string& path,
                                       MappedResource& resource) {
  TRACE_DURATION("dart", "LoadFromNamespace", "path", path);

  // openat of a path with a leading '/' ignores the namespace fd.
  FXL_CHECK(path[0] != '/');

  fsl::SizedVmo resource_vmo;
  if (namespc == nullptr) {
    if (!fsl::VmoFromFilename(path, &resource_vmo)) {
      FXL_LOG(ERROR) << "Failed to open " << path;
      return false;
    }
  } else {
    fxl::UniqueFD root_dir(fdio_ns_opendir(namespc));
    if (!root_dir.is_valid()) {
      FXL_LOG(ERROR) << "Failed to open namespace";
      return false;
    }

    if (!fsl::VmoFromFilenameAt(root_dir.get(), path, &resource_vmo)) {
      FXL_LOG(ERROR) << "Failed to open " << path;
      return false;
    }
  }

  return LoadFromVmo(path, std::move(resource_vmo), resource);
}

bool MappedResource::LoadFromVmo(const std::string& path,
                                 fsl::SizedVmo resource_vmo,
                                 MappedResource& resource) {
  uintptr_t addr;
  zx_status_t status =
      zx::vmar::root_self().map(0, resource_vmo.vmo(), 0, resource_vmo.size(),
                                ZX_VM_FLAG_PERM_READ, &addr);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to map " << path << ": "
                   << zx_status_get_string(status);
    return false;
  }

  resource.address_ = reinterpret_cast<void*>(addr);
  resource.size_ = resource_vmo.size();
  return true;
}

MappedResource::~MappedResource() {
  if (address_ != nullptr) {
    zx::vmar::root_self().unmap(reinterpret_cast<uintptr_t>(address_), size_);
    address_ = nullptr;
    size_ = 0;
  }
}

}  // namespace dart_content_handler

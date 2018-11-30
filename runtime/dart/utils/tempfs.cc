// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "tempfs.h"

#include <string>
#include <thread>

#include <lib/fdio/namespace.h>
#include <lib/fxl/logging.h>
#include <lib/memfs/memfs.h>
#include <zircon/errors.h>
#include <zircon/status.h>
#include <zircon/syscalls.h>

#include "topaz/lib/deprecated_loop/message_loop.h"

namespace {

constexpr char kTmpPath[] = "/tmp";
constexpr size_t kMaxTmpPages = 1024;

void DispatchTempMemFS() {
  deprecated_loop::MessageLoop loop;
  zx_status_t status = memfs_install_at_with_page_limit(
      loop.dispatcher(), kMaxTmpPages, kTmpPath);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to install a /tmp memfs: "
                   << zx_status_get_string(status);
    return;
  }
  loop.Run();
}

}  // namespace

namespace fuchsia {
namespace dart {

// Set up a memfs bound to /tmp in the process-wide namespace that has the
// lifetime of the process.
void SetupRunnerTemp() {
  std::thread thread(DispatchTempMemFS);
  thread.detach();
}

void SetupComponentTemp(fdio_ns_t* ns) {
  // TODO(zra): Should isolates share a /tmp file system within a process, or
  // should isolates each get their own private memfs for /tmp? For now,
  // sharing the process-wide /tmp simplifies hot reload since the hot reload
  // devfs requires sharing between the service isolate and the app isolates.
  zx_status_t status;
  fdio_flat_namespace_t* rootns;
  status = fdio_ns_export_root(&rootns);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to export root ns: "
                   << zx_status_get_string(status);
    return;
  }

  zx_handle_t tmp_dir_handle;
  for (size_t i = 0; i < rootns->count; i++) {
    if (strcmp(rootns->path[i], kTmpPath) == 0) {
      tmp_dir_handle = rootns->handle[i];
    } else {
      zx_handle_close(rootns->handle[i]);
      rootns->handle[i] = ZX_HANDLE_INVALID;
    }
  }
  free(rootns);
  rootns = nullptr;

  status = fdio_ns_bind(ns, kTmpPath, tmp_dir_handle);
  if (status != ZX_OK) {
    zx_handle_close(tmp_dir_handle);
    FXL_LOG(ERROR) << "Failed to bind /tmp directory into isolate namespace: "
                   << zx_status_get_string(status);
  }
}

}  // namespace dart
}  // namespace fuchsia

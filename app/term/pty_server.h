// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_APP_TERM_PTY_SERVER_H_
#define TOPAZ_APP_TERM_PTY_SERVER_H_

#include <zx/process.h>

#include <functional>
#include <vector>

#include "lib/fsl/tasks/fd_waiter.h"
#include "lib/fxl/files/unique_fd.h"

namespace term {

class PTYServer {
 public:
  using ReceiveCallback =
      std::function<void(const void* bytes, size_t num_bytes)>;
  using TerminationCallback = std::function<void()>;

  PTYServer();
  ~PTYServer();

  void SetWindowSize(uint32_t width, uint32_t height);

  zx_status_t Run(std::vector<std::string> argv,
                  ReceiveCallback receive_callback,
                  TerminationCallback termination_callback);

  void Write(const void* bytes, size_t num_bytes);

 private:
  void Wait();

  ReceiveCallback receive_callback_;
  TerminationCallback termination_callback_;
  fxl::UniqueFD pty_;
  fsl::FDWaiter pty_waiter_;
  zx::process process_;
};

}  // namespace term

#endif  // TOPAZ_APP_TERM_PTY_SERVER_H_

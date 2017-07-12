// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_MOTERM_COMMAND_H_
#define APPS_MOTERM_COMMAND_H_

#include <launchpad/launchpad.h>
#include <mx/process.h>
#include <mx/socket.h>
#include <mxio/util.h>

#include <functional>
#include <vector>

#include "lib/ftl/files/unique_fd.h"
#include "lib/ftl/functional/closure.h"
#include "lib/mtl/io/redirection.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/mtl/tasks/message_loop_handler.h"

namespace moterm {

class Command : mtl::MessageLoopHandler {
 public:
  using ReceiveCallback =
      std::function<void(const void* bytes, size_t num_bytes)>;

  Command();
  ~Command();

  bool Start(std::vector<std::string> command,
             std::vector<mtl::StartupHandle> startup_handles,
             ReceiveCallback receive_callback,
             ftl::Closure termination_callback);

  void SendData(const void* bytes, size_t num_bytes);

 private:
  // |mtl::MessageLoopHandler|:
  void OnHandleReady(mx_handle_t handle, mx_signals_t pending, uint64_t count);

  ftl::Closure termination_callback_;
  ReceiveCallback receive_callback_;
  mx::socket stdin_;
  mx::socket stdout_;
  mx::socket stderr_;

  mtl::MessageLoop::HandlerKey termination_key_ = 0;
  mtl::MessageLoop::HandlerKey out_key_ = 0;
  mtl::MessageLoop::HandlerKey err_key_ = 0;
  mx::process process_;
};

}  // namespace moterm

#endif  // APPS_MOTERM_COMMAND_H_

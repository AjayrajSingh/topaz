// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_MOTERM_SHELL_CONTROLLER_H_
#define APPS_MOTERM_SHELL_CONTROLLER_H_

#include <deque>
#include <map>
#include <string>
#include <vector>

#include <mx/channel.h>
#include <mx/vmo.h>

#include "lib/fidl/c/waiter/async_waiter.h"
#include "lib/fidl/cpp/waiter/default.h"
#include "lib/ftl/macros.h"
#include "lib/mtl/io/redirection.h"
#include "lib/mtl/vmo/strings.h"

namespace moterm {

// Implements the controller protocol of the default shell. The controller
// exchanges control messages with the shell over an mx::channel.
//
// For the protocol description, see
// magenta/third_party/uapp/dash/src/controller.h.
class ShellController {
 public:
  ShellController();
  ~ShellController();

  // Returns the system command for starting the default shell.
  std::vector<std::string> GetShellCommand();

  // Returns the startup handles needed for initializing the default shell.
  std::vector<mtl::StartupHandle> GetStartupHandles();

  // Starts the communication with shell.
  void Start();

 private:
  bool HandleGetHistory();
  void HandleAddToHistory(const std::string& entry);

  void ReadCommand();
  void WaitForShell();
  static void WaitComplete(mx_status_t result,
                           mx_signals_t pending,
                           void* context);

  const FidlAsyncWaiter* waiter_ = fidl::GetDefaultAsyncWaiter();
  FidlAsyncWaitID wait_id_ = 0;

  mx::channel channel_;

  std::deque<std::string> terminal_history_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ShellController);
};

}  // namespace moterm

#endif  // APPS_MOTERM_SHELL_CONTROLLER_H_

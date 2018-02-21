// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_APP_TERM_SHELL_CONTROLLER_H_
#define TOPAZ_APP_TERM_SHELL_CONTROLLER_H_

#include <async/cpp/auto_wait.h>
#include <zx/channel.h>
#include <zx/vmo.h>

#include <deque>
#include <map>
#include <string>
#include <vector>

#include "lib/fsl/io/redirection.h"
#include "lib/fsl/vmo/strings.h"
#include "lib/fxl/macros.h"
#include "topaz/app/term/history.h"

namespace term {

// Implements the controller protocol of the default shell. The controller
// exchanges control messages with the shell over an zx::channel.
//
// For the protocol description, see
// zircon/third_party/uapp/dash/src/controller.h.
class ShellController : public History::Client {
 public:
  ShellController(History* history);
  ~ShellController() override;

  // Returns the system command for starting the default shell.
  std::vector<std::string> GetShellCommand();

  // Returns the startup handles needed for initializing the default shell.
  std::vector<fsl::StartupHandle> GetStartupHandles();

  // Starts the communication with shell.
  void Start();

  // Stops communication with the shell.
  void Terminate();

  // History::Client:
  void OnRemoteEntry(const std::string& entry) override;

 private:
  bool SendBackHistory(std::vector<std::string> entries);
  void HandleAddToHistory(const std::string& entry);

  async_wait_result_t ReadCommand();

  // Ledger-backed store for terminal history.
  History* history_;

  async::AutoWait wait_;

  zx::channel channel_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ShellController);
};

}  // namespace term

#endif  // TOPAZ_APP_TERM_SHELL_CONTROLLER_H_

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/shell_controller.h"

#include <async/cpp/auto_wait.h>
#include <async/default.h>
#include <string.h>
#include <zircon/processargs.h>

#include <sstream>

#include "lib/fxl/files/directory.h"
#include "lib/fxl/files/file.h"
#include "lib/fxl/files/path.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/strings/split_string.h"

namespace term {

namespace {
constexpr char kShell[] = "/boot/bin/sh";
constexpr size_t kMaxHistoryEntrySize = 1024;

constexpr char kGetHistoryCommand[] = "get_history";
constexpr char kAddLocalEntryCommand[] = "add_local_entry:";
constexpr char kAddRemoteEntryCommand[] = "add_remote_entry:";

std::string SerializeHistory(const std::vector<std::string>& history) {
  std::stringstream output_stream;
  for (const std::string& command : history) {
    output_stream << command << std::endl;
  }

  return output_stream.str();
}

}  // namespace

ShellController::ShellController(History* history)
    : history_(history), wait_(async_get_default()) {
  history_->RegisterClient(this);
  wait_.set_trigger(ZX_CHANNEL_READABLE | ZX_CHANNEL_PEER_CLOSED);
  wait_.set_handler(
      [this](async_t* async, zx_status_t status,
             const zx_packet_signal_t* signal) { return ReadCommand(); });
}

ShellController::~ShellController() {}

std::vector<std::string> ShellController::GetShellCommand() {
  return {std::string(kShell)};
}

std::vector<fsl::StartupHandle> ShellController::GetStartupHandles() {
  std::vector<fsl::StartupHandle> ret;

  zx::channel shell_handle;
  zx_status_t status = zx::channel::create(0, &channel_, &shell_handle);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create an zx::channel for the shell, status: "
                   << status;
    return {};
  }
  fsl::StartupHandle startup_handle;
  startup_handle.id = PA_USER1;
  startup_handle.handle = std::move(shell_handle);
  ret.push_back(std::move(startup_handle));

  return ret;
}

void ShellController::Start() {
  wait_.Cancel();
  wait_.set_object(channel_.get());
  wait_.Begin();
}

// Stops communication with the shell.
void ShellController::Terminate() {
  wait_.Cancel();
  history_->UnregisterClient(this);
}

void ShellController::OnRemoteEntry(const std::string& entry) {
  // Ignore entries that are too big for the controller protocol to handle.
  if (entry.size() > kMaxHistoryEntrySize) {
    return;
  }
  std::string command = kAddRemoteEntryCommand + entry;
  zx_status_t status =
      channel_.write(0, command.data(), command.size(), nullptr, 0);
  if (status != ZX_OK && status != ZX_ERR_NO_MEMORY) {
    FXL_LOG(ERROR) << "Failed to write a " << kAddRemoteEntryCommand
                   << " command, status: " << status;
  }
}

bool ShellController::SendBackHistory(std::vector<std::string> entries) {
  const std::string history_str = SerializeHistory(entries);

  fsl::SizedVmo data;
  if (!fsl::VmoFromString(history_str, &data)) {
    FXL_LOG(ERROR) << "Failed to write terminal history to a vmo.";
    return false;
  }

  const zx_handle_t handles[] = {data.vmo().release()};
  const std::string command = "";
  zx_status_t status =
      channel_.write(0, command.data(), command.size(), handles, 1);
  if (status != ZX_OK) {
    FXL_LOG(ERROR)
        << "Failed to write the terminal history response to channel.";
    zx_handle_close(handles[0]);
    return false;
  }
  return true;
}

void ShellController::HandleAddToHistory(const std::string& entry) {
  history_->AddEntry(entry);
}

async_wait_result_t ShellController::ReadCommand() {
  // The commands should not be bigger than the name of the command + max size
  // of a history entry.
  char buffer[kMaxHistoryEntrySize + 100];
  uint32_t num_bytes = 0;
  zx_status_t rv =
      channel_.read(ZX_CHANNEL_READ_MAY_DISCARD, buffer, sizeof(buffer),
                    &num_bytes, nullptr, 0, nullptr);
  if (rv == ZX_OK) {
    const std::string command = std::string(buffer, num_bytes);
    if (command == kGetHistoryCommand) {
      history_->ReadInitialEntries([this](std::vector<std::string> entries) {
        SendBackHistory(std::move(entries));
      });
    } else if (command.substr(0, strlen(kAddLocalEntryCommand)) ==
               kAddLocalEntryCommand) {
      HandleAddToHistory(command.substr(strlen(kAddLocalEntryCommand)));
    } else {
      FXL_LOG(ERROR) << "Unrecognized shell command: " << command;
      return ASYNC_WAIT_FINISHED;
    }

    return ASYNC_WAIT_AGAIN;
  } else if (rv == ZX_ERR_SHOULD_WAIT) {
    return ASYNC_WAIT_AGAIN;
  } else if (rv == ZX_ERR_BUFFER_TOO_SMALL) {
    // Ignore the command.
    FXL_LOG(WARNING) << "The command sent by shell didn't fit in the buffer.";
    return ASYNC_WAIT_AGAIN;
  } else if (rv == ZX_ERR_PEER_CLOSED) {
    channel_.reset();
    return ASYNC_WAIT_FINISHED;
  } else {
    FXL_DCHECK(false) << "Unhandled zx_status_t: " << rv;
    return ASYNC_WAIT_FINISHED;
  }
}

}  // namespace term

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/pty_server.h"

#include <fcntl.h>
#include <fdio/io.h>
#include <fdio/private.h>
#include <launchpad/launchpad.h>
#include <lib/async/default.h>
#include <poll.h>
#include <unistd.h>
#include <zircon/device/pty.h>
#include <zircon/status.h>

#include "lib/fxl/logging.h"

namespace term {
namespace {

std::vector<const char*> GetArgv(const std::vector<std::string>& command) {
  std::vector<const char*> argv;
  argv.reserve(command.size());
  for (const auto& arg : command)
    argv.push_back(arg.c_str());
  return argv;
}

}  // namespace

PTYServer::PTYServer() {
  pty_.reset(open("/dev/misc/ptmx", O_RDWR | O_NONBLOCK));
  if (!pty_.is_valid())
    FXL_LOG(ERROR) << "Failed to create pty: " << errno;
}

PTYServer::~PTYServer() = default;

void PTYServer::SetWindowSize(uint32_t width, uint32_t height) {
  pty_window_size_t window = {
      .width = width,
      .height = height,
  };

  ioctl_pty_set_window_size(pty_.get(), &window);
}

zx_status_t PTYServer::Run(std::vector<std::string> command,
                           ReceiveCallback receive_callback,
                           TerminationCallback termination_callback) {
  FXL_DCHECK(!command.empty());

  int client_fd = openat(pty_.get(), "0", O_RDWR | O_NONBLOCK);
  if (client_fd < 0) {
    FXL_LOG(ERROR) << "Failed to create client pty: " << strerror(errno);
    return ZX_ERR_NOT_FOUND;
  }

  auto argv = GetArgv(command);
  launchpad_t* lp;
  launchpad_create(0, argv[0], &lp);
  launchpad_load_from_file(lp, argv[0]);
  launchpad_set_args(lp, argv.size(), argv.data());
  launchpad_transfer_fd(lp, client_fd, FDIO_FLAG_USE_FOR_STDIO);
  launchpad_clone(
      lp, LP_CLONE_FDIO_NAMESPACE | LP_CLONE_ENVIRON | LP_CLONE_DEFAULT_JOB);

  zx_handle_t proc;
  const char* errmsg;
  zx_status_t status = launchpad_go(lp, &proc, &errmsg);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Cannot run executable " << argv[0] << " due to error "
                   << status << " (" << zx_status_get_string(status)
                   << "): " << errmsg;
    return status;
  }
  process_.reset(proc);

  receive_callback_ = std::move(receive_callback);
  termination_callback_ = std::move(termination_callback);
  Wait();
  return ZX_OK;
}

void PTYServer::Wait() {
  pty_waiter_.Wait(
      [this](zx_status_t status, uint32_t events) {
        if (status != ZX_OK) {
          FXL_LOG(ERROR) << "Failed to wait on PTY.";
          return;
        }

        if (events & POLLIN) {
          char buffer[1024];
          ssize_t len = 0;
          while ((len = read(pty_.get(), buffer, sizeof(buffer))) > 0)
            receive_callback_(buffer, len);
          Wait();
          return;
        }

        if (events & (POLLRDHUP | POLLHUP))
          termination_callback_();
      },
      pty_.get(), POLLIN | POLLRDHUP | POLLHUP);
}

void PTYServer::Write(const void* bytes, size_t num_bytes) {
  ssize_t remaining = num_bytes;
  ssize_t pos = 0;
  while (remaining) {
    ssize_t len = write(pty_.get(), static_cast<const char*>(bytes) + pos, remaining);
    if (len < 0) {
      FXL_LOG(ERROR) << "Failed to send";
      return;
    }
    pos += len;
    remaining -= len;
  }
}

}  // namespace term

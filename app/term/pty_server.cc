// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/pty_server.h"

#include <fcntl.h>

#include <fuchsia/hardware/pty/c/fidl.h>
#include <lib/async/default.h>
#include <lib/fdio/fd.h>
#include <lib/fdio/io.h>
#include <lib/fdio/private.h>
#include <lib/fdio/spawn.h>
#include <lib/zx/channel.h>
#include <src/lib/fxl/logging.h>
#include <zircon/status.h>

namespace term {
namespace {

std::vector<const char*> GetArgv(const std::vector<std::string>& command) {
  std::vector<const char*> argv;
  argv.reserve(command.size() + 1);
  for (const auto& arg : command)
    argv.push_back(arg.c_str());
  argv.push_back(nullptr);
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
  fuchsia_hardware_pty_WindowSize window = {
      .width = width,
      .height = height,
  };

  fdio_t* io = fdio_unsafe_fd_to_io(pty_.get());
  zx_status_t status;
  fuchsia_hardware_pty_DeviceSetWindowSize(fdio_unsafe_borrow_channel(io),
                                           &window, &status);
  fdio_unsafe_release(io);
}

zx_status_t PTYServer::Run(std::vector<std::string> command,
                           ReceiveCallback receive_callback,
                           TerminationCallback termination_callback) {
  FXL_DCHECK(!command.empty());

  fdio_t* io = fdio_unsafe_fd_to_io(pty_.get());
  if (!io) {
    FXL_LOG(ERROR)
        << "Failed to create client PTY: couldn't make PTMX fdio connection";
    return ZX_ERR_INTERNAL;
  }

  zx::channel device_channel, client_channel;
  zx_status_t status = zx::channel::create(0, &device_channel, &client_channel);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create client PTY channels: "
                   << zx_status_get_string(status);
    return status;
  }

  zx_status_t fidl_status = fuchsia_hardware_pty_DeviceOpenClient(
      fdio_unsafe_borrow_channel(io), 1 /* client id */,
      device_channel.release(), &status);
  fdio_unsafe_release(io);
  if (fidl_status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create client PTY (FIDL error): "
                   << zx_status_get_string(fidl_status);
    return fidl_status;
  }
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create client PTY: "
                   << zx_status_get_string(status);
    return status;
  }

  int client_fd;
  status = fdio_fd_create(client_channel.release(), &client_fd);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Failed to create client PTY FD: "
                   << zx_status_get_string(status);
    return status;
  }
  fcntl(client_fd, F_SETFL, O_NONBLOCK);

  fdio_spawn_action_t action;
  action.action = FDIO_SPAWN_ACTION_TRANSFER_FD;
  action.fd.local_fd = client_fd;
  action.fd.target_fd = FDIO_FLAG_USE_FOR_STDIO;

  auto argv = GetArgv(command);

  zx_handle_t proc;
  char err_msg[FDIO_SPAWN_ERR_MSG_MAX_LENGTH];
  status = fdio_spawn_etc(
      ZX_HANDLE_INVALID, FDIO_SPAWN_CLONE_ALL & ~FDIO_SPAWN_CLONE_STDIO,
      argv[0], argv.data(), nullptr, 1, &action, &proc, err_msg);
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Cannot run executable " << argv[0] << " due to error "
                   << status << " (" << zx_status_get_string(status)
                   << "): " << err_msg;
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
    ssize_t len =
        write(pty_.get(), static_cast<const char*>(bytes) + pos, remaining);
    if (len < 0) {
      FXL_LOG(ERROR) << "Failed to send";
      return;
    }
    pos += len;
    remaining -= len;
  }
}

}  // namespace term

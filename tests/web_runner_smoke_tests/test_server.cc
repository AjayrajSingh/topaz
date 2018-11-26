// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/tests/web_runner_smoke_tests/test_server.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

namespace web_runner_smoke_tests {

bool TestServer::FindAndBindPort() {
  socket_.reset(socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP));
  if (!socket_.is_valid()) {
    fprintf(stderr, "socket() failed: %d %s\n", errno, strerror(errno));
    return false;
  }

  int port_to_try = 9999;

  struct sockaddr_in6 addr = {};
  addr.sin6_family = AF_INET6;
  addr.sin6_port = htons(port_to_try);
  addr.sin6_addr = in6addr_loopback;

  if (bind(socket_.get(), reinterpret_cast<struct sockaddr*>(&addr),
           sizeof(addr)) < 0) {
    fprintf(stderr, "bind() failed: %d %s\n", errno, strerror(errno));
    return false;
  }
  port_ = port_to_try;

  if (listen(socket_.get(), 2) < 0) {
    fprintf(stderr, "listen() failed: %d %s\n", errno, strerror(errno));
    return false;
  }

  return true;
}

bool TestServer::Accept() {
  conn_.reset(accept(socket_.get(), nullptr, nullptr));
  return conn_.is_valid();
}

bool TestServer::Read(std::vector<char>* buf) {
  ssize_t ret = read(conn_.get(), buf->data(), buf->size());
  if (ret < 0)
    return false;
  buf->resize(ret);
  return true;
}

bool TestServer::Write(const std::string& buf) {
  ssize_t ret = write(conn_.get(), buf.data(), buf.size());
  return ret == static_cast<ssize_t>(buf.size());
}

}  // namespace web_runner_smoke_tests
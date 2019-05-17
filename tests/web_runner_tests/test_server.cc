// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/tests/web_runner_tests/test_server.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

namespace web_runner_tests {

bool TestServer::FindAndBindPort() {
  socket_.reset(socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP));
  if (!socket_.is_valid()) {
    fprintf(stderr, "socket() failed: %d %s\n", errno, strerror(errno));
    return false;
  }

  struct sockaddr_in6 addr = {};
  addr.sin6_family = AF_INET6;
  addr.sin6_addr = in6addr_loopback;

  if (bind(socket_.get(), reinterpret_cast<struct sockaddr*>(&addr),
           sizeof(addr)) < 0) {
    fprintf(stderr, "bind() failed: %d %s\n", errno, strerror(errno));
    return false;
  }

  socklen_t addrlen = sizeof(addr);
  if (getsockname(socket_.get(), reinterpret_cast<struct sockaddr*>(&addr),
                  &addrlen) < 0) {
    fprintf(stderr, "getsockname() failed: %d %s\n", errno, strerror(errno));
    return false;
  }
  if (addrlen != sizeof(addr)) {
    fprintf(stderr, "getsockname() returned unexpected length %d vs %lu\n",
            addrlen, sizeof(addr));
    return false;
  }

  port_ = ntohs(addr.sin6_port);

  if (listen(socket_.get(), 2) < 0) {
    fprintf(stderr, "listen() failed: %d %s\n", errno, strerror(errno));
    return false;
  }

  return true;
}

void TestServer::Close() { socket_.reset(); }

bool TestServer::Accept() {
  conn_.reset(accept(socket_.get(), nullptr, nullptr));
  return conn_.is_valid();
}

bool TestServer::Read(std::string* buf) {
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

bool TestServer::WriteContent(const std::string& content) {
  std::ostringstream response;
  response << "HTTP/1.1 200 OK\r\n"
           << "Content-Length: " << content.size() << "\r\n\r\n"
           << content;
  return Write(response.str());
}

}  // namespace web_runner_tests

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_TESTS_WEB_RUNNER_TESTS_TEST_SERVER_H_
#define TOPAZ_TESTS_WEB_RUNNER_TESTS_TEST_SERVER_H_

#include <string>
#include <vector>

#include <lib/fxl/files/unique_fd.h>

namespace web_runner_tests {

// This is a simple TCP server that binds to a random port on localhost and
// serves a single connection.
class TestServer {
 public:
  // This attempts to find an available port the server to.
  bool FindAndBindPort();

  // Closes the bound socket file descriptor, cancelling any pending |Accept|.
  void Close();

  // This accepts exactly one incoming connection.
  bool Accept();

  // This reads data from the currently open connection into the provided
  // buffer. On success, this resizes |buf| to the number of bytes read.
  bool Read(std::vector<char>* buf);

  // Writes data from |buf| into the currently open connection.
  bool Write(const std::string& buf);

  // Writes message content into the currently open connection, preceeded by an
  // appropriate HTTP response header.
  bool WriteContent(const std::string& content);

  // Port number in use.
  int port() const { return port_; }

 private:
  fxl::UniqueFD conn_;
  fxl::UniqueFD socket_;
  int port_ = -1;
};

}  // namespace web_runner_tests

#endif  // TOPAZ_TESTS_WEB_RUNNER_TESTS_TEST_SERVER_H_

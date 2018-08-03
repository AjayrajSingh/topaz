// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/sys/cpp/fidl.h>
#include <gtest/gtest.h>
#include <lib/component/cpp/environment_services_helper.h>
#include <lib/fxl/strings/string_printf.h>

#include "topaz/tests/web_runner_smoke_tests/test_server.h"

TEST(WebRunnerTest, Smoke) {
  web_runner_smoke_tests::TestServer server;

  ASSERT_TRUE(server.FindAndBindPort());

  fuchsia::sys::LaunchInfo launch_info;
  launch_info.url =
      fxl::StringPrintf("http://localhost:%d/foo.html", server.port());

  fuchsia::sys::LauncherSyncPtr launcher;
  component::GetEnvironmentServices()->ConnectToService(launcher.NewRequest());

  fuchsia::sys::ComponentControllerSyncPtr controller;
  launcher->CreateComponent(std::move(launch_info), controller.NewRequest());

  ASSERT_TRUE(server.Accept());

  std::string expected_prefix = "GET /foo.html HTTP";
  std::vector<char> buf;
  buf.resize(4096);

  ASSERT_TRUE(server.Read(&buf));
  ASSERT_GE(buf.size(), expected_prefix.size());

  EXPECT_EQ(expected_prefix, std::string(buf.data(), expected_prefix.size()));

  std::string page = "<!doctype html><img src=\"/img.png\">";
  std::string response = "HTTP/1.1 200 OK\r\n";
  response += fxl::StringPrintf("Content-Length: %ld\r\n", page.size());
  response += "\r\n" + page;

  ASSERT_TRUE(server.Write(response));

  expected_prefix = "GET /img.png HTTP";
  buf.resize(4096);
  ASSERT_TRUE(server.Read(&buf));

  ASSERT_GE(buf.size(), expected_prefix.size());
  EXPECT_EQ(expected_prefix, std::string(buf.data(), expected_prefix.size()));
}

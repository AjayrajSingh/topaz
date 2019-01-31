// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/sys/cpp/fidl.h>
#include <gtest/gtest.h>
#include <lib/component/cpp/environment_services_helper.h>
#include <lib/fxl/strings/string_printf.h>

#include "topaz/tests/web_runner_tests/test_server.h"

// This is a black box smoke test for whether the web runner in a given system
// is capable of performing basic operations.
//
// This currently tests if launching a component with an HTTP URL triggers an
// HTTP GET for the main resource, and if an HTML response with an <img> tag
// triggers a subresource load for the image.
TEST(WebRunnerIntegrationTest, Smoke) {
  web_runner_tests::TestServer server;

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

  ASSERT_TRUE(server.WriteContent("<!doctype html><img src=\"/img.png\">"));

  expected_prefix = "GET /img.png HTTP";
  buf.resize(4096);
  ASSERT_TRUE(server.Read(&buf));

  ASSERT_GE(buf.size(), expected_prefix.size());
  EXPECT_EQ(expected_prefix, std::string(buf.data(), expected_prefix.size()));
}

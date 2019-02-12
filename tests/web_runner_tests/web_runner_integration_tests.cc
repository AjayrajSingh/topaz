// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/sys/cpp/fidl.h>
#include <gtest/gtest.h>
#include <lib/component/cpp/environment_services_helper.h>
#include <lib/fit/function.h>
#include <lib/fxl/logging.h>
#include <lib/fxl/strings/string_printf.h>
#include <lib/gtest/real_loop_fixture.h>
#include <zircon/status.h>

#include "topaz/tests/web_runner_tests/chromium_context.h"
#include "topaz/tests/web_runner_tests/test_server.h"

// This file contains a subset of adapted Chromium Fuchsia tests to make sure
// nothing broke on the import boundary.
//
// See also: https://chromium.googlesource.com/chromium/src/+/master/fuchsia
namespace {

// This is a black box smoke test for whether the web runner in a given system
// is capable of performing basic operations.
//
// This tests if launching a component with an HTTP URL triggers an HTTP GET for
// the main resource, and if an HTML response with an <img> tag triggers a
// subresource load for the image.
//
// See also:
// https://chromium.googlesource.com/chromium/src/+/master/fuchsia/runners/web/web_runner_smoke_test.cc
TEST(WebRunnerIntegrationTest, Smoke) {
  web_runner_tests::TestServer server;
  FXL_CHECK(server.FindAndBindPort());

  fuchsia::sys::LaunchInfo launch_info;
  launch_info.url =
      fxl::StringPrintf("http://localhost:%d/foo.html", server.port());

  fuchsia::sys::LauncherSyncPtr launcher;
  component::GetEnvironmentServices()->ConnectToService(launcher.NewRequest());

  fuchsia::sys::ComponentControllerSyncPtr controller;
  launcher->CreateComponent(std::move(launch_info), controller.NewRequest());

  ASSERT_TRUE(server.Accept());

  std::string expected_prefix = "GET /foo.html HTTP";
  // We need to overallocate the first time to drain the read since we expect
  // the subsresource load on the same connection.
  std::string buf(4096, 0);
  ASSERT_TRUE(server.Read(&buf));
  EXPECT_EQ(expected_prefix, buf.substr(0, expected_prefix.size()));

  FXL_CHECK(server.WriteContent("<!doctype html><img src=\"/img.png\">"));

  expected_prefix = "GET /img.png HTTP";
  buf.resize(expected_prefix.size());
  ASSERT_TRUE(server.Read(&buf));

  ASSERT_GE(buf.size(), expected_prefix.size());
  EXPECT_EQ(expected_prefix, std::string(buf.data(), expected_prefix.size()));
}

class MockNavigationEventObserver
    : public chromium::web::NavigationEventObserver {
 public:
  // |chromium::web::NavigationEventObserver|
  void OnNavigationStateChanged(
      chromium::web::NavigationEvent change,
      OnNavigationStateChangedCallback callback) override {
    if (on_navigation_state_changed_) {
      on_navigation_state_changed_(std::move(change));
    }

    callback();
  }

  void set_on_navigation_state_changed(
      fit::function<void(chromium::web::NavigationEvent)> fn) {
    on_navigation_state_changed_ = std::move(fn);
  }

 private:
  fit::function<void(chromium::web::NavigationEvent)>
      on_navigation_state_changed_;
};

class ChromiumAppTest : public gtest::RealLoopFixture {
 protected:
  ChromiumAppTest()
      : chromium_(component::StartupContext::CreateFromStartupInfo().get()) {}

  ChromiumContext* chromium() { return &chromium_; }

 private:
  ChromiumContext chromium_;
};

// This test ensures that we can interact with the chromium.web FIDL.
//
// See also
// https://chromium.googlesource.com/chromium/src/+/master/fuchsia/engine/browser/context_impl_browsertest.cc
TEST_F(ChromiumAppTest, CreateAndNavigate) {
  MockNavigationEventObserver navigation_event_observer;
  fidl::Binding<chromium::web::NavigationEventObserver>
      navigation_event_observer_binding(&navigation_event_observer);
  chromium()->frame()->SetNavigationEventObserver(
      navigation_event_observer_binding.NewBinding());
  navigation_event_observer_binding.set_error_handler([](zx_status_t status) {
    FAIL() << "navigation_event_observer_binding: "
           << zx_status_get_string(status);
  });

  std::string observed_url;
  std::string observed_title;

  navigation_event_observer.set_on_navigation_state_changed(
      [this, &navigation_event_observer, &observed_url,
       &observed_title](chromium::web::NavigationEvent change) {
        if (change.url) {
          observed_url = *change.url;
        }
        if (change.title) {
          observed_title = *change.title;
        }

        EXPECT_FALSE(change.is_error);

        if (!(observed_url.empty() || observed_title.empty())) {
          navigation_event_observer.set_on_navigation_state_changed(nullptr);
          QuitLoop();
        }
      });

  // TODO(NET-2089): Without this (or even if this is moved down below
  // |FindAndBindPort|), this test flakes about 10% of the time. Reordering the
  // tests such that this test executes first also deflakes it.
  sleep(1);

  web_runner_tests::TestServer server;
  FXL_CHECK(server.FindAndBindPort());

  const std::string url =
      fxl::StringPrintf("http://localhost:%d/foo.html", server.port());
  chromium()->Navigate(url);

  ASSERT_TRUE(server.Accept());

  const std::string expected_prefix = "GET /foo.html HTTP";
  std::string buf(expected_prefix.size(), 0);
  ASSERT_TRUE(server.Read(&buf));
  EXPECT_EQ(expected_prefix, buf.substr(0, expected_prefix.size()));
  FXL_CHECK(server.WriteContent(R"(<!doctype html>
      <html>
        <head>
          <title>Test title!</title>
        </head>
      </html>)"));

  EXPECT_FALSE(RunLoopWithTimeout(zx::sec(5)))
      << "Timed out waiting for navigation events";

  EXPECT_EQ(url, observed_url);
  EXPECT_EQ("Test title!", observed_title);
}

}  // namespace
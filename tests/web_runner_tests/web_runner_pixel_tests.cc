// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <iomanip>
#include <map>
#include <string>
#include <vector>

#include <chromium/web/cpp/fidl.h>
#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <fuchsia/ui/policy/cpp/fidl.h>
#include <fuchsia/ui/scenic/cpp/fidl.h>
#include <gtest/gtest.h>
#include <lib/component/cpp/startup_context.h>
#include <lib/fdio/util.h>
#include <lib/fit/defer.h>
#include <lib/fit/function.h>
#include <lib/fsl/vmo/vector.h>
#include <lib/fxl/files/file.h>
#include <lib/fxl/logging.h>
#include <lib/fxl/strings/string_printf.h>
#include <lib/fxl/threading/thread.h>
#include <lib/gtest/real_loop_fixture.h>
#include <lib/zx/time.h>

#include "topaz/tests/web_runner_tests/test_server.h"

namespace {

// Max time to wait in failure cases before bailing.
constexpr zx::duration kTimeout = zx::sec(15);

std::map<uint32_t, size_t> Histogram(
    const fuchsia::ui::scenic::ScreenshotData& screenshot) {
  EXPECT_GT(screenshot.info.width, 0u);
  EXPECT_GT(screenshot.info.height, 0u);

  std::vector<uint8_t> data;
  EXPECT_TRUE(fsl::VectorFromVmo(screenshot.data, &data))
      << "Failed to read screenshot";

  std::map<uint32_t, size_t> histogram;
  const uint32_t* bitmap = reinterpret_cast<const uint32_t*>(data.data());
  const size_t size = screenshot.info.width * screenshot.info.height;
  EXPECT_EQ(size * sizeof(uint32_t), data.size());
  for (size_t i = 0; i < size; ++i) {
    ++histogram[bitmap[i]];
  }

  return histogram;
}

// Runs the test server on its own thread, with proper cleanup to prevent
// deadlock. |serve| must terminate after |server->Accept()| returns false.
auto ServeAsync(web_runner_tests::TestServer* server, fit::closure serve) {
  auto server_thread = std::make_unique<fxl::Thread>(std::move(serve));
  server_thread->Run();
  // The socket must be closed before the thread goes out of scope so that any
  // blocking |Accept| calls terminate so that |serve| can terminate.
  return fit::defer(
      [server, server_thread = std::move(server_thread)] { server->Close(); });
}

// Responds to a GET request, testing that the request looks as expected.
void MockHttpGetResponse(web_runner_tests::TestServer* server,
                         const char* resource) {
  std::string expected_prefix = fxl::StringPrintf("GET /%s HTTP", resource);
  std::vector<char> buf;
  // |Read| requires preallocate (see sys/socket.h: read)
  buf.resize(4096);

  EXPECT_TRUE(server->Read(&buf));
  EXPECT_GE(buf.size(), expected_prefix.size());
  EXPECT_EQ(expected_prefix, std::string(buf.data(), expected_prefix.size()));
  std::string content;
  FXL_CHECK(files::ReadFileToString(fxl::StringPrintf("/pkg/data/%s", resource),
                                    &content));
  FXL_CHECK(server->WriteContent(content));
}

// Base fixture for web runner pixel tests, containing Scenic and presentation
// setup, and screenshot utilities.
class WebRunnerPixelTest : public gtest::RealLoopFixture {
 protected:
  WebRunnerPixelTest()
      : context_(component::StartupContext::CreateFromStartupInfo()) {
    scenic_ =
        context_->ConnectToEnvironmentService<fuchsia::ui::scenic::Scenic>();
    scenic_.set_error_handler([](zx_status_t status) {
      FAIL() << "Lost connection to Scenic: " << status;
    });
  }

  component::StartupContext* context() { return context_.get(); }

  // Gets a view token for presentation by |RootPresenter|. See also
  // garnet/examples/ui/hello_base_view
  zx::eventpair CreatePresentationViewToken() {
    zx::eventpair view_holder_token, view_token;
    FXL_CHECK(zx::eventpair::create(0u, &view_holder_token, &view_token) ==
              ZX_OK);

    auto presenter =
        context_->ConnectToEnvironmentService<fuchsia::ui::policy::Presenter>();
    presenter.set_error_handler(
        [](zx_status_t status) { FAIL() << "presenter: " << status; });
    presenter->Present2(std::move(view_holder_token), nullptr);

    return view_token;
  }

  bool ScreenshotUntil(
      fit::function<bool(fuchsia::ui::scenic::ScreenshotData)> condition,
      zx::duration timeout = kTimeout) {
    zx::time start = zx::clock::get_monotonic();
    while (zx::clock::get_monotonic() - start <= timeout) {
      fuchsia::ui::scenic::ScreenshotData screenshot;
      bool ok;
      scenic_->TakeScreenshot(
          [this, &screenshot, &ok](
              fuchsia::ui::scenic::ScreenshotData screenshot_in, bool status) {
            ok = status;
            screenshot = std::move(screenshot_in);
            QuitLoop();
          });

      if (!RunLoopWithTimeout(timeout) && ok &&
          condition(std::move(screenshot))) {
        return true;
      }
    }

    return false;
  }

  void ExpectSolidColor(uint32_t argb) {
    std::map<uint32_t, size_t> histogram;

    FXL_LOG(INFO) << "Looking for color " << std::hex << argb;
    EXPECT_TRUE(ScreenshotUntil(
        [argb, &histogram](fuchsia::ui::scenic::ScreenshotData screenshot) {
          histogram = Histogram(screenshot);
          FXL_LOG(INFO) << histogram[argb] << " px";
          return histogram[argb] > 0u;
        }));

    histogram.erase(argb);
    EXPECT_EQ((std::map<uint32_t, size_t>){}, histogram) << "Unexpected colors";
  }

 private:
  std::unique_ptr<component::StartupContext> context_;
  fuchsia::sys::ComponentControllerPtr runner_ctrl_;
  fuchsia::ui::scenic::ScenicPtr scenic_;
};

// Loads a static page with a solid color via the component framework and
// verifies that the color is the only color onscreen.
TEST_F(WebRunnerPixelTest, Static) {
  static constexpr uint32_t kTargetColor = 0xffff00ff;

  web_runner_tests::TestServer server;
  FXL_CHECK(server.FindAndBindPort());

  // Chromium and the Fuchsia network package loader both send us requests. This
  // may go away after MI4-1807; although the race seems to be in Modular, the
  // fix may remove the unnecessary net request in component framework.
  auto serve = ServeAsync(&server, [&server] {
    while (server.Accept()) {
      MockHttpGetResponse(&server, "static.html");
    }
  });

  component::Services services;
  fuchsia::sys::ComponentControllerPtr controller;

  context()->launcher()->CreateComponent(
      {.url =
           fxl::StringPrintf("http://localhost:%d/static.html", server.port()),
       .directory_request = services.NewRequest()},
      controller.NewRequest());

  // Present the view.
  services.ConnectToService<fuchsia::ui::app::ViewProvider>()->CreateView(
      CreatePresentationViewToken(), nullptr, nullptr);

  ExpectSolidColor(kTargetColor);
}

// This fixture uses chromium.web FIDL services to interact with Chromium.
class ChromiumFidlTest : public WebRunnerPixelTest,
                         chromium::web::NavigationEventObserver {
 protected:
  ChromiumFidlTest() : navigation_event_observer_binding_(this) {
    auto context_provider =
        context()
            ->ConnectToEnvironmentService<chromium::web::ContextProvider>();
    context_provider.set_error_handler(
        [](zx_status_t status) { FAIL() << "context_provider: " << status; });

    zx_handle_t incoming_service_clone =
        fdio_service_clone(context()->incoming_services()->directory().get());
    FXL_CHECK(incoming_service_clone != ZX_HANDLE_INVALID);

    chromium::web::CreateContextParams params;
    params.service_directory = zx::channel(incoming_service_clone);
    context_provider->Create(std::move(params), chromium_context_.NewRequest());
    chromium_context_.set_error_handler(
        [](zx_status_t status) { FAIL() << "chromium_context_: " << status; });

    chromium_context_->CreateFrame(chromium_frame_.NewRequest());
    chromium_frame_.set_error_handler(
        [](zx_status_t status) { FAIL() << "chromium_frame_: " << status; });

    // Bind ourselves as a NavigationEventObserver on this frame.
    chromium_frame_->SetNavigationEventObserver(
        navigation_event_observer_binding_.NewBinding());
    navigation_event_observer_binding_.set_error_handler(
        [](zx_status_t status) {
          FAIL() << "navigation_event_observer_binding_: " << status;
        });

    // And create a view for the frame.
    chromium_frame_->CreateView2(CreatePresentationViewToken(), nullptr,
                                 nullptr);
    chromium_frame_->GetNavigationController(navigation_.NewRequest());
    navigation_.set_error_handler(
        [](zx_status_t status) { FAIL() << "navigation_: " << status; });
  }

  void LaunchPage(const std::string& url) { navigation_->LoadUrl(url, {}); }

  fit::function<void(chromium::web::NavigationEvent)>
      on_navigation_state_changed_;

 private:
  // |chromium::web::NavigationEventObserver|
  void OnNavigationStateChanged(
      chromium::web::NavigationEvent change,
      OnNavigationStateChangedCallback callback) override {
    if (on_navigation_state_changed_) {
      on_navigation_state_changed_(std::move(change));
    }

    callback();
  }

  chromium::web::NavigationControllerPtr navigation_;
  chromium::web::ContextPtr chromium_context_;
  chromium::web::FramePtr chromium_frame_;
  fidl::Binding<chromium::web::NavigationEventObserver>
      navigation_event_observer_binding_;
};

// Loads a static page with a solid color via chromium.web interfaces and
// verifies that the color is the only color onscreen.
TEST_F(ChromiumFidlTest, StaticChromiumFidl) {
  static constexpr uint32_t kTargetColor = 0xffff00ff;

  web_runner_tests::TestServer server;
  FXL_CHECK(server.FindAndBindPort());

  auto serve = ServeAsync(&server, [&server] {
    FXL_LOG(INFO) << "Waiting for HTTP request from Chromium";
    ASSERT_TRUE(server.Accept())
        << "Did not receive HTTP request from Chromium";
    MockHttpGetResponse(&server, "static.html");
  });

  std::string url =
      fxl::StringPrintf("http://localhost:%d/static.html", server.port());

  on_navigation_state_changed_ = [this,
                                  url](chromium::web::NavigationEvent change) {
    if (change.url && *change.url == url) {
      EXPECT_FALSE(change.is_error);
      on_navigation_state_changed_ = nullptr;

      QuitLoop();
    }
  };

  LaunchPage(url);

  EXPECT_FALSE(RunLoopWithTimeout(kTimeout))
      << "Timed out waiting for OnNavigationStateChanged";

  ExpectSolidColor(kTargetColor);
}

}  // namespace
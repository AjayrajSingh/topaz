// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/ui/app/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <fuchsia/webview/cpp/fidl.h>

#include "lib/component/cpp/testing/fake_component.h"
#include "lib/component/cpp/testing/test_with_context.h"
#include "topaz/runtime/web_runner_prototype/runner.h"

namespace web {
namespace testing {

class FakeWebView : public fuchsia::ui::app::ViewProvider,
                    public fuchsia::ui::viewsv1::ViewProvider,
                    public fuchsia::webview::WebView {
 public:
  FakeWebView() {
    component_.AddPublicService(view_provider_bindings_.GetHandler(this));
    component_.AddPublicService(v1_view_provider_bindings_.GetHandler(this));
    service_provider_.AddService(web_view_bindings_.GetHandler(this));
  }

  void Register(component::testing::FakeLauncher& fake_launcher) {
    component_.Register("web_view", fake_launcher);
  }

  // |fuchsia::ui::app::ViewProvider|:
  void CreateView(
      zx::eventpair view_token,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services)
      final {
    ++create_view_count_;
    service_provider_.AddBinding(std::move(incoming_services));
  }

  // |fuchsia::ui::viewsv1::ViewProvider|:
  void CreateView(
      fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner>
          view_owner_request,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) final {
    CreateView(zx::eventpair(view_owner_request.TakeChannel().release()),
               std::move(services), nullptr);
  }

  // |fuchsia::webview::WebView|:
  void ClearCookies() final {}

  void SetUrl(fidl::StringPtr url) final { last_url_ = *url; }

  void SetWebRequestDelegate(
      fidl::InterfaceHandle<fuchsia::webview::WebRequestDelegate> delegate)
      final {}

  int create_view_count_ = 0;
  std::string last_url_;

 private:
  component::testing::FakeComponent component_;
  fidl::BindingSet<fuchsia::ui::app::ViewProvider> view_provider_bindings_;
  fidl::BindingSet<fuchsia::ui::viewsv1::ViewProvider>
      v1_view_provider_bindings_;
  fidl::BindingSet<fuchsia::webview::WebView> web_view_bindings_;
  component::ServiceProviderImpl service_provider_;
};

class RunnerTest : public component::testing::TestWithContext {
 public:
  void SetUp() final {
    TestWithContext::SetUp();
    fake_web_view_ = std::make_unique<FakeWebView>();
    fake_web_view_->Register(controller().fake_launcher());
    runner_ = std::make_unique<Runner>(TakeContext());
  }

  void TearDown() final {
    runner_.reset();
    fake_web_view_.reset();
    TestWithContext::TearDown();
  }

  FakeWebView* web_view() const { return fake_web_view_.get(); }
  Runner* runner() const { return runner_.get(); }

 private:
  std::unique_ptr<Runner> runner_;
  std::unique_ptr<FakeWebView> fake_web_view_;
};

TEST_F(RunnerTest, Trivial) {}

TEST_F(RunnerTest, CreatesWebView) {
  component::Services runner_services;

  fuchsia::sys::Package package;
  package.resolved_url = "http://example.com/resolved_url.html";
  fuchsia::sys::StartupInfo startup_info;
  startup_info.launch_info.url = "http://example.com/launch_url.html";
  startup_info.launch_info.directory_request = runner_services.NewRequest();
  fuchsia::sys::ComponentControllerPtr controller;

  runner()->StartComponent(std::move(package), std::move(startup_info),
                           controller.NewRequest());

  fuchsia::ui::viewsv1::ViewProviderPtr view_provider;
  runner_services.ConnectToService(view_provider.NewRequest());

  fuchsia::ui::viewsv1token::ViewOwnerPtr view_owner;
  fuchsia::sys::ServiceProviderPtr services;
  view_provider->CreateView(view_owner.NewRequest(), services.NewRequest());

  RunLoopUntilIdle();

  EXPECT_EQ(1, web_view()->create_view_count_);
  EXPECT_EQ("http://example.com/resolved_url.html", web_view()->last_url_);
}

}  // namespace testing
}  // namespace web

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/ui/app/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>

#include <lib/app_driver/cpp/module_driver.h>
#include <lib/async-loop/cpp/loop.h>
#include <lib/fsl/vmo/strings.h>
#include <lib/integration_testing/cpp/reporting.h>
#include <lib/integration_testing/cpp/testing.h>

namespace {

// This needs to be encoded as JSON.
constexpr char kTestUrl[] = "\"http://localhost/\"";
constexpr char kOutputUrlLinkName[] = "output_url";

// A module which tests that the `web_view` reads its input URL from the correct
// intent parameter. The `web_view` mod will write its input URL (from its
// root/null Link) back into an output link ("output_url").
class TestModule : fuchsia::modular::LinkWatcher {
 public:
  TestModule(modular::ModuleHost* module_host,
             fidl::InterfaceRequest<
                 fuchsia::ui::app::ViewProvider> /*view_provider_request*/)
      : module_host_(module_host),
        module_context_(module_host_->module_context()),
        output_url_link_watcher_binding_(this) {
    modular::testing::Init(module_host->startup_context(), __FILE__);
    StartTest();
  }

  TestModule(modular::ModuleHost* const module_host,
             fidl::InterfaceRequest<
                 fuchsia::ui::viewsv1::ViewProvider> /*view_provider_request*/)
      : TestModule(
            module_host,
            fidl::InterfaceRequest<fuchsia::ui::app::ViewProvider>(nullptr)) {}

  // Step 1: Start `web_view` and give it a URL (via root link), and setup
  // observation for output URL (via "output_url" link).
  void StartTest() {
    fuchsia::modular::Intent intent;
    intent.action = "launch_url";
    intent.handler = "web_view";

    // input: the input URL is delivered over the root link.
    {
      fuchsia::modular::LinkPtr input_url_link;
      module_host_->module_context()->GetLink(nullptr,
                                              input_url_link.NewRequest());
      fuchsia::mem::Buffer buf;
      FXL_CHECK(fsl::VmoFromString(kTestUrl, &buf));
      input_url_link->Set(nullptr, std::move(buf));

      fuchsia::modular::IntentParameter p;
      p.data.set_link_name(nullptr);
      intent.parameters->push_back(std::move(p));
    }
    // output: the input URL is echo'd back and received over the output link.
    {
      module_host_->module_context()->GetLink(kOutputUrlLinkName,
                                              output_url_link_.NewRequest());
      output_url_link_->Watch(output_url_link_watcher_binding_.NewBinding());

      fuchsia::modular::IntentParameter p;
      p.name = kOutputUrlLinkName;
      p.data.set_link_name(kOutputUrlLinkName);
      intent.parameters->push_back(std::move(p));
    }

    module_host_->module_context()->AddModuleToStory(
        "web_view", std::move(intent), web_view_controller_.NewRequest(),
        nullptr, [](fuchsia::modular::StartModuleStatus status) {
          FXL_CHECK(status == fuchsia::modular::StartModuleStatus::SUCCESS);
        });
  }

  // Step 2: We arrive here from watching the output Link. Crash-fail if we
  // don't get the expected value.
  void HandleOutputUrl(std::string output_link_value) {
    FXL_CHECK(output_link_value == kTestUrl)
        << "Unexpected output url. Actual = " << output_link_value;
    output_link_value_point_.Pass();

    // signal that we want to shutdown (our session shell integration test
    // driver looks for this signal and then terminates us.)
    modular::testing::Signal(modular::testing::kTestShutdown);
  }

  // Called from ModuleDriver.
  void Terminate(const std::function<void()>& done) {
    modular::testing::Done(done);
  }

 private:
  // |fuchsia::modular::LinkWatcher|
  void Notify(fuchsia::mem::Buffer json) {
    std::string output_link_value;
    FXL_CHECK(fsl::StringFromVmo(json, &output_link_value));
    // The link value is JSON-encoded.
    if (output_link_value != "null") {
      HandleOutputUrl(output_link_value);
    }
  }

  modular::ModuleHost* const module_host_;
  fuchsia::modular::ModuleContext* const module_context_;
  fuchsia::modular::ModuleControllerPtr web_view_controller_;

  modular::testing::TestPoint output_link_value_point_{
      "Received expected URL in output link"};

  fuchsia::modular::LinkPtr output_url_link_;
  fidl::Binding<fuchsia::modular::LinkWatcher> output_url_link_watcher_binding_;

  FXL_DISALLOW_COPY_AND_ASSIGN(TestModule);
};

}  // namespace

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  auto context = component::StartupContext::CreateFromStartupInfo();
  modular::ModuleDriver<TestModule> driver(context.get(),
                                           [&loop] { loop.Quit(); });
  loop.Run();
  return 0;
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>
#include <memory>

#include <auth/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>

#include "lib/app/cpp/startup_context.h"
#include "lib/backoff/exponential_backoff.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/fsl/vmo/strings.h"
#include "lib/fxl/command_line.h"
#include "lib/fxl/log_settings_command_line.h"
#include "lib/network_wrapper/network_wrapper_impl.h"
#include "topaz/auth_providers/google/factory_impl.h"

namespace {

namespace http = ::fuchsia::net::oldhttp;

class GoogleAuthProviderApp {
 public:
  GoogleAuthProviderApp()
      : loop_(&kAsyncLoopConfigMakeDefault),
        startup_context_(fuchsia::sys::StartupContext::CreateFromStartupInfo()),
        trace_provider_(loop_.async()),
        network_wrapper_(
            loop_.async(), std::make_unique<backoff::ExponentialBackoff>(),
            [this] {
              return startup_context_
                  ->ConnectToEnvironmentService<http::HttpService>();
            }),
        factory_impl_(loop_.async(), startup_context_.get(),
                      &network_wrapper_) {
    FXL_DCHECK(startup_context_);
  }

  ~GoogleAuthProviderApp() { loop_.Quit(); }

  void Run() {
    startup_context_->outgoing().AddPublicService<auth::AuthProviderFactory>(
        [this](fidl::InterfaceRequest<auth::AuthProviderFactory> request) {
          factory_impl_.Bind(std::move(request));
        });
    loop_.Run();
  }

 private:
  async::Loop loop_;
  std::unique_ptr<fuchsia::sys::StartupContext> startup_context_;
  trace::TraceProvider trace_provider_;
  network_wrapper::NetworkWrapperImpl network_wrapper_;

  google_auth_provider::FactoryImpl factory_impl_;

  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderApp);
};

}  // namespace

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line)) {
    return 1;
  }

  GoogleAuthProviderApp app;
  app.Run();

  return 0;
}

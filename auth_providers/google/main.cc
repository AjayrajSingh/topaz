// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>
#include <memory>

#include <fuchsia/auth/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>

#include "lib/backoff/exponential_backoff.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/fsl/syslogger/init.h"
#include "lib/fsl/vmo/strings.h"
#include "lib/fxl/command_line.h"
#include "lib/network_wrapper/network_wrapper_impl.h"
#include "topaz/auth_providers/google/factory_impl.h"
#include "topaz/auth_providers/google/settings.h"

namespace {

namespace http = ::fuchsia::net::oldhttp;
using fuchsia::auth::AuthProviderFactory;
using google_auth_provider::Settings;

class GoogleAuthProviderApp {
 public:
  GoogleAuthProviderApp(fxl::CommandLine command_line)
      : loop_(&kAsyncLoopConfigAttachToThread),
        startup_context_(component::StartupContext::CreateFromStartupInfo()),
        trace_provider_(loop_.dispatcher()),
        network_wrapper_(
            loop_.dispatcher(), std::make_unique<backoff::ExponentialBackoff>(),
            [this] {
              return startup_context_
                  ->ConnectToEnvironmentService<http::HttpService>();
            }),
        factory_impl_(loop_.dispatcher(), startup_context_.get(),
                      &network_wrapper_, CreateSettings(command_line)) {
    FXL_DCHECK(startup_context_);
  }

  ~GoogleAuthProviderApp() { loop_.Quit(); }

  void Run() {
    startup_context_->outgoing().AddPublicService<AuthProviderFactory>(
        [this](fidl::InterfaceRequest<AuthProviderFactory> request) {
          factory_impl_.Bind(std::move(request));
        });
    loop_.Run();
  }

 private:
  async::Loop loop_;
  std::unique_ptr<component::StartupContext> startup_context_;
  trace::TraceProvider trace_provider_;
  network_wrapper::NetworkWrapperImpl network_wrapper_;
  google_auth_provider::FactoryImpl factory_impl_;

  static Settings CreateSettings(fxl::CommandLine command_line) {
    Settings settings;
    if (command_line.HasOption("glif")) {
      settings.use_glif = true;
    } else if (command_line.HasOption("redcarpet")) {
      settings.use_glif = false;
    }
    if (command_line.HasOption("fuchsiaendpoint")) {
      settings.use_dedicated_endpoint = true;
    } else if (command_line.HasOption("oauthendpoint")) {
      settings.use_dedicated_endpoint = false;
    }
    return settings;
  }

  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderApp);
};

}  // namespace

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  fsl::InitLoggerFromCommandLine(command_line, {"auth"});

  GoogleAuthProviderApp app(command_line);
  app.Run();

  return 0;
}

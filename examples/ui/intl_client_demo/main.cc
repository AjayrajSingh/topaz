// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <lib/async-loop/default.h>
#include <lib/trace-provider/provider.h>
#include <lib/ui/base_view/cpp/view_provider_component.h>

#include "intl_client_demo_view.h"
#include "src/lib/fxl/command_line.h"
#include "src/lib/fxl/log_settings_command_line.h"
int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToCurrentThread);
  trace::TraceProviderWithFdio trace_provider(loop.dispatcher());

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line)) {
    return 1;
  }

  FXL_LOG(INFO) << "Creating ViewProviderComponent";
  scenic::ViewProviderComponent component(
      [](scenic::ViewContext view_context) {
        FXL_LOG(INFO) << "Calling ViewFactory";
        auto view = std::make_unique<examples::IntlClientDemoView>(
            std::move(view_context));
        FXL_LOG(INFO) << "Constructed IntlClientDemoView";
        return view;
      },
      &loop);

  loop.Run();
  FXL_LOG(INFO) << "Reached end of main";
  return 0;
}

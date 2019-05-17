// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "src/lib/fxl/command_line.h"
#include "src/lib/fxl/log_settings_command_line.h"
#include "lib/ui/base_view/cpp/view_provider_component.h"
#include "topaz/examples/ui/view_config_demo/view_config_demo_view.h"

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  trace::TraceProvider trace_provider(loop.dispatcher());

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line)) {
    return 1;
  }

  FXL_LOG(INFO) << "Creating ViewProviderComponent";
  scenic::ViewProviderComponent component(
      [&loop](scenic::ViewContext view_context) {
        FXL_LOG(INFO) << "Calling ViewFactory";
        auto view = std::make_unique<examples::ViewConfigDemoView>(
            std::move(view_context));
        FXL_LOG(INFO) << "Constructed ViewConfigDemoView";
        return view;
      },
      &loop);

  loop.Run();
  FXL_LOG(INFO) << "Reached end of main";
  return 0;
}

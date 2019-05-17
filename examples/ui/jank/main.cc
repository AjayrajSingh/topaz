// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "src/lib/fxl/command_line.h"
#include "src/lib/fxl/log_settings_command_line.h"
#include "lib/ui/base_view/cpp/view_provider_component.h"
#include "topaz/examples/ui/jank/jank_view.h"

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  trace::TraceProvider trace_provider(loop.dispatcher());

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line))
    return 1;

  scenic::ViewProviderComponent component(
      [&loop](scenic::ViewContext view_context) {
        auto font_provider =
            view_context.startup_context
                ->ConnectToEnvironmentService<fuchsia::fonts::Provider>();
        return std::make_unique<examples::JankView>(std::move(view_context),
                                                    std::move(font_provider));
      },
      &loop);

  loop.Run();
  return 0;
}

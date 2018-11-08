// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "lib/fxl/command_line.h"
#include "lib/fxl/log_settings_command_line.h"
#include "lib/ui/base_view/cpp/view_provider_component.h"
#include "topaz/bin/ui/skottie_viewer/view.h"

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line))
    return 1;

  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  trace::TraceProvider trace_provider(loop.dispatcher());

  scenic::ViewProviderComponent component(
      [&loop](scenic::ViewContext view_context) {
        return std::make_unique<skottie::View>(std::move(view_context));
      },
      &loop);

  loop.Run();
  return 0;
}

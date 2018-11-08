// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "lib/fxl/command_line.h"
#include "lib/fxl/log_settings_command_line.h"
#include "lib/ui/base_view/cpp/view_provider_component.h"
#include "topaz/examples/mediaplayer/mediaplayer_skia/mediaplayer_view.h"

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  trace::TraceProvider trace_provider(loop.dispatcher());

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  if (!fxl::SetLogSettingsFromCommandLine(command_line))
    return 1;

  examples::MediaPlayerParams params(command_line);
  if (!params.is_valid())
    return 1;

  scenic::ViewProviderComponent component(
      [&loop, &params](scenic::ViewContext view_context) {
        return std::make_unique<examples::MediaPlayerView>(
            std::move(view_context), &loop, params);
      },
      &loop);

  loop.Run();
  return 0;
}

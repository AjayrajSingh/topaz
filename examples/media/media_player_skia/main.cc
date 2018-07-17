// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>

#include "lib/fxl/command_line.h"
#include "lib/ui/view_framework/view_provider_app.h"
#include "topaz/examples/media/media_player_skia/media_player_view.h"

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  examples::MediaPlayerParams params(command_line);
  if (!params.is_valid()) {
    return 1;
  }

  async::Loop loop(&kAsyncLoopConfigAttachToThread);

  mozart::ViewProviderApp app(
      [&loop, &params](mozart::ViewContext view_context) {
        return std::make_unique<examples::MediaPlayerView>(
            &loop, std::move(view_context.view_manager),
            std::move(view_context.view_owner_request),
            view_context.startup_context, params);
      });

  loop.Run();
  return 0;
}

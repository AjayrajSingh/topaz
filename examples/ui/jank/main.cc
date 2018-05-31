// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "lib/ui/view_framework/view_provider_app.h"
#include "topaz/examples/ui/jank/jank_view.h"

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigMakeDefault);
  trace::TraceProvider trace_provider(loop.async());

  mozart::ViewProviderApp app([](mozart::ViewContext view_context) {
    return std::make_unique<examples::JankView>(
        std::move(view_context.view_manager),
        std::move(view_context.view_owner_request),
        view_context.startup_context
            ->ConnectToEnvironmentService<fonts::FontProvider>());
  });

  loop.Run();
  return 0;
}

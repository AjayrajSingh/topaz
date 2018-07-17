// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <trace-provider/provider.h>

#include "lib/fxl/log_settings_command_line.h"
#include "lib/fxl/logging.h"
#include "topaz/app/term/app.h"
#include "topaz/app/term/term_params.h"

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  term::TermParams params;
  if (!fxl::SetLogSettingsFromCommandLine(command_line) ||
      !params.Parse(command_line)) {
    FXL_LOG(ERROR) << "Missing or invalid parameters. See README.";
    return 1;
  }

  async::Loop loop(&kAsyncLoopConfigAttachToThread);
  trace::TraceProvider trace_provider(loop.dispatcher());

  term::App app(std::move(params));
  loop.Run();
  return 0;
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <async/cpp/loop.h>
#include <trace-provider/provider.h>

#include "topaz/shell/ermine_user_shell/app.h"

int main(int argc, const char** argv) {
  async_loop_config_t config = {
      .make_default_for_current_thread = true,
  };

  async::Loop loop(&config);
  trace::TraceProvider trace_provider(loop.async());

  ermine_user_shell::App app;
  loop.Run();
  return 0;
}

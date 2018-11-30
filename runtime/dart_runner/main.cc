// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>

#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart_runner/dart_runner.h"
#include "topaz/runtime/dart/utils/tempfs.h"

int main(int argc, const char** argv) {
  deprecated_loop::MessageLoop loop;
  trace::TraceProvider provider(loop.dispatcher());
  fuchsia::dart::SetupRunnerTemp();
  dart_runner::DartRunner runner;
  loop.Run();
  return 0;
}

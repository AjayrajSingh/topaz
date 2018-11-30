// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>
#include <cstdlib>

#include "runner.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart/utils/tempfs.h"

int main(int argc, char const* argv[]) {
  deprecated_loop::MessageLoop loop;

  trace::TraceProvider provider(loop.dispatcher());
  FML_DCHECK(provider.is_valid()) << "Trace provider must be valid.";

  // Set up the process-wide /tmp memfs.
  fuchsia::dart::SetupRunnerTemp();

  FML_DLOG(INFO) << "Flutter application services initialized.";

  flutter::Runner runner;

  loop.Run();

  FML_DLOG(INFO) << "Flutter application services terminated.";

  return EXIT_SUCCESS;
}

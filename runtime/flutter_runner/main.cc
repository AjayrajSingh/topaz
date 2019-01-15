// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>
#include <trace/event.h>

#include <cstdlib>

#include "runner.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart/utils/tempfs.h"

int main(int argc, char const* argv[]) {
  deprecated_loop::MessageLoop loop;

  fbl::unique_ptr<trace::TraceProvider> provider;
  {
    TRACE_DURATION("flutter", "CreateTraceProvider");
    bool already_started;
    // Use CreateSynchronously to prevent loss of early events.
    trace::TraceProvider::CreateSynchronously(
        loop.dispatcher(), "flutter_runner", &provider, &already_started);
  }

  // Set up the process-wide /tmp memfs.
  fuchsia::dart::SetupRunnerTemp();

  FML_DLOG(INFO) << "Flutter application services initialized.";

  flutter::Runner runner;

  loop.Run();

  FML_DLOG(INFO) << "Flutter application services terminated.";

  return EXIT_SUCCESS;
}

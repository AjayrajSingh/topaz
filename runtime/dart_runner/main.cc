// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>

#include "lib/fsl/tasks/message_loop.h"
#include "topaz/runtime/dart_runner/dart_application_runner.h"

int main(int argc, const char** argv) {
  fsl::MessageLoop loop;
  trace::TraceProvider provider(loop.async());
  dart_runner::DartApplicationRunner runner;
  loop.Run();
  return 0;
}

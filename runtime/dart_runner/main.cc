// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <lib/async-loop/cpp/loop.h>
#include <lib/async-loop/default.h>
#include <lib/syslog/cpp/logger.h>
#include <trace-provider/provider.h>
#include <trace/event.h>

#include "third_party/dart/runtime/include/dart_api.h"
#include "topaz/runtime/dart/utils/files.h"
#include "topaz/runtime/dart/utils/tempfs.h"
#include "topaz/runtime/dart_runner/dart_runner.h"
#include "topaz/runtime/dart_runner/logging.h"

#if !defined(DART_PRODUCT)
// Register native symbol information for the Dart VM's profiler.
static void RegisterProfilerSymbols(const char* symbols_path,
                                    const char* dso_name) {
  std::string* symbols = new std::string();
  if (dart_utils::ReadFileToString(symbols_path, symbols)) {
    Dart_AddSymbols(dso_name, symbols->data(), symbols->size());
  } else {
    FX_LOGF(FATAL, LOG_TAG, "Failed to load %s", symbols_path);
  }
}
#endif  // !defined(DART_PRODUCT)

int main(int argc, const char** argv) {
  async::Loop loop(&kAsyncLoopConfigAttachToCurrentThread);

  syslog::InitLogger();

  std::unique_ptr<trace::TraceProviderWithFdio> provider;
  {
    TRACE_DURATION("dart", "CreateTraceProvider");
    bool already_started;
    // Use CreateSynchronously to prevent loss of early events.
    trace::TraceProviderWithFdio::CreateSynchronously(
        loop.dispatcher(), "dart_runner", &provider, &already_started);
  }

#if !defined(DART_PRODUCT)
#if defined(AOT_RUNTIME)
  RegisterProfilerSymbols(
      "pkg/data/libdart_precompiled_runtime.dartprofilersymbols",
      "libdart_precompiled_runtime.so");
  RegisterProfilerSymbols("pkg/data/dart_aot_runner.dartprofilersymbols", "");
#else
  RegisterProfilerSymbols("pkg/data/libdart_jit.dartprofilersymbols",
                          "libdart_jit.so");
  RegisterProfilerSymbols("pkg/data/dart_jit_runner.dartprofilersymbols", "");
#endif  // defined(AOT_RUNTIME)
#endif  // !defined(DART_PRODUCT)

  dart_utils::RunnerTemp runner_temp;
  dart_runner::DartRunner runner;
  loop.Run();
  return 0;
}

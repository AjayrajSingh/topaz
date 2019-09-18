// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/tests/benchmarks/gfx_benchmarks.h"

#include "src/lib/fxl/logging.h"

void AddGraphicsBenchmarks(benchmarking::BenchmarksRunner* benchmarks_runner) {
  FXL_DCHECK(benchmarks_runner != nullptr);

  struct Param {
    std::string benchmark_name;
    std::string command;
    std::optional<std::string> flutter_app_name;
    std::string renderer_params;
  };

  constexpr char kImageGridFlutterX3Command[] =
      "present_view fuchsia-pkg://fuchsia.com/tile_view#meta/tile_view.cmx "
      "image_grid_flutter image_grid_flutter image_grid_flutter";

  // clang-format off
  std::vector<Param> params = {
    //
    // image_grid_flutter
    //
    {"fuchsia.scenic.image_grid_flutter_noclipping_noshadows", "present_view image_grid_flutter", "image_grid_flutter", "--unshadowed --clipping_disabled"},
    {"fuchsia.scenic.image_grid_flutter_noshadows", "present_view image_grid_flutter", "image_grid_flutter", "--unshadowed --clipping_enabled"},
    {"fuchsia.scenic.image_grid_flutter_stencil_shadow_volume", "present_view image_grid_flutter", "image_grid_flutter", "--stencil_shadow_volume --clipping_enabled"},

    //
    // image_grid_flutter x3
    //
    // TODO: Support tracking multiple flutter apps of the same name in
    // process_scenic_trace.
    {"fuchsia.scenic.image_grid_flutter_x3_noclipping_noshadows", kImageGridFlutterX3Command, {}, "--unshadowed --clipping_disabled",},
    {"fuchsia.scenic.image_grid_flutter_x3_noshadows", kImageGridFlutterX3Command, {}, "--unshadowed --clipping_enabled",},
    {"fuchsia.scenic.image_grid_flutter_x3_stencil_shadow_volume", kImageGridFlutterX3Command, {}, "--stencil_shadow_volume --clipping_enabled",},
  };
  // clang-format on

  for (const auto& param : params) {
    std::string out_file = benchmarks_runner->MakePerfResultsOutputFilename("scenic");

    // clang-format off
    std::vector<std::string> full_command = {
        "/pkgfs/packages/scenic_benchmarks/0/bin/run_scenic_benchmark.sh",
        "--out_file", out_file,
        "--benchmark_label", param.benchmark_name,
        "--cmd", param.command,
    };
    // clang-format on

    if (param.flutter_app_name) {
      full_command.push_back("--flutter_app_name");
      full_command.push_back(*param.flutter_app_name);
      full_command.push_back("--sleep_before_trace");
      full_command.push_back("5");
    }

    full_command.push_back(param.renderer_params);

    benchmarks_runner->AddCustomBenchmark(param.benchmark_name, full_command,
                                          out_file);
  }
}

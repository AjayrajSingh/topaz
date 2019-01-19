#!/boot/bin/sh
#
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This script runs all gfx benchmarks for the Garnet layer. It is called by
# benchmarks.sh.

# Scenic performance tests.
RUN_SCENIC_BENCHMARK="/pkgfs/packages/scenic_benchmarks/0/bin/run_scenic_benchmark.sh"


# Arguments to runbench_exec for Scenic benchmarks:
#
# runbench_exec
#   "${OUT_DIR}/${BENCHMARK}.json"             # Output file path.
#   "${RUN_SCENIC_BENCHMARK}"                  # Scenic benchmark runner, followed by
#                                              #   its arguments.
#   --out_dir "${OUT_DIR}"                     # Output directory.
#   --out_file "${OUT_DIR}/${BENCHMARK}.json"  # Output file path.
#   --benchmark_label "${BENCHMARK}"           # Label for benchmark.
#   --cmd "test_binary"                        # Binary that is being benchmarked.
#   --unshadowed --clipping_disabled           # Renderer parameters.


#
# image_grid_flutter
#
BENCHMARK="fuchsia.scenic.image_grid_flutter_noclipping_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view fuchsia-pkg://fuchsia.com/image_grid_flutter#meta/image_grid_flutter.cmx"  \
    --flutter_app_name 'image_grid_flutter'   \
    --sleep_before_trace 5                    \
    --unshadowed --clipping_disabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view fuchsia-pkg://fuchsia.com/image_grid_flutter#meta/image_grid_flutter.cmx"  \
    --flutter_app_name 'image_grid_flutter'   \
    --sleep_before_trace 5                    \
    --unshadowed --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_ssdo"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view fuchsia-pkg://fuchsia.com/image_grid_flutter#meta/image_grid_flutter.cmx"  \
    --flutter_app_name 'image_grid_flutter'   \
    --sleep_before_trace 5                    \
    --screen_space_shadows --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view fuchsia-pkg://fuchsia.com/image_grid_flutter#meta/image_grid_flutter.cmx"  \
    --flutter_app_name 'image_grid_flutter'   \
    --sleep_before_trace 5                    \
    --shadow_map --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_moment_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view fuchsia-pkg://fuchsia.com/image_grid_flutter#meta/image_grid_flutter.cmx"  \
    --flutter_app_name 'image_grid_flutter'   \
    --sleep_before_trace 5                    \
    --moment_shadow_map --clipping_enabled

#
# image_grid_flutter x3
#
# TODO: Support tracking multiple flutter apps of the same name in
# process_scenic_trace.
IMAGE_GRID_FLUTTER_X3_COMMAND="set_root_view fuchsia-pkg://fuchsia.com/tile_view#meta/tile_view.cmx image_grid_flutter image_grid_flutter image_grid_flutter"
BENCHMARK="fuchsia.scenic.image_grid_flutter_x3_noclipping_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${IMAGE_GRID_FLUTTER_X3_COMMAND}"  \
    --unshadowed --clipping_disabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_x3_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${IMAGE_GRID_FLUTTER_X3_COMMAND}"  \
    --unshadowed --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_x3_ssdo"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${IMAGE_GRID_FLUTTER_X3_COMMAND}"  \
    --screen_space_shadows --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_x3_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${IMAGE_GRID_FLUTTER_X3_COMMAND}"  \
    --shadow_map --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_x3_moment_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${IMAGE_GRID_FLUTTER_X3_COMMAND}"  \
    --moment_shadow_map --clipping_enabled

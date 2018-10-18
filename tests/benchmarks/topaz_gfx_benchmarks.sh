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
    --cmd "set_root_view image_grid_flutter"  \
    --unshadowed --clipping_disabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view image_grid_flutter"  \
    --unshadowed --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_ssdo"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view image_grid_flutter"  \
    --screen_space_shadows --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view image_grid_flutter"  \
    --shadow_map --clipping_enabled

BENCHMARK="fuchsia.scenic.image_grid_flutter_moment_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "set_root_view image_grid_flutter"  \
    --moment_shadow_map --clipping_enabled

#
# image_grid_flutter x3
#
IMAGE_GRID_FLUTTER_X3_COMMAND="set_root_view tile_view image_grid_flutter image_grid_flutter image_grid_flutter"
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

# choreography
CHOREOGRAPHY_COMMAND="run basemgr --test --enable_presenter --account_provider=dev_token_manager --device_shell=dev_device_shell --device_shell_args=--test_timeout_ms=60000 --user_shell=dev_user_shell --user_shell_args=--root_module=choreography --story_shell=mondrian"
BENCHMARK="fuchsia.scenic.choreography_noclipping_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${CHOREOGRAPHY_COMMAND}"           \
    --unshadowed --clipping_disabled

BENCHMARK="fuchsia.scenic.choreography_noshadows"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${CHOREOGRAPHY_COMMAND}"           \
    --unshadowed --clipping_enabled

BENCHMARK="fuchsia.scenic.choreography_ssdo"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${CHOREOGRAPHY_COMMAND}"           \
    --screen_space_shadows --clipping_enabled

BENCHMARK="fuchsia.scenic.choreography_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${CHOREOGRAPHY_COMMAND}"           \
    --shadow_map --clipping_enabled

BENCHMARK="fuchsia.scenic.choreography_moment_shadow_map"
runbench_exec "${OUT_DIR}/${BENCHMARK}.json"  \
    "${RUN_SCENIC_BENCHMARK}"                 \
    --out_dir "${OUT_DIR}"                    \
    --out_file "${OUT_DIR}/${BENCHMARK}.json" \
    --benchmark_label "${BENCHMARK}"          \
    --cmd "${CHOREOGRAPHY_COMMAND}"           \
    --moment_shadow_map --clipping_enabled

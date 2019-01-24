#!/boot/bin/sh
#
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This script runs all startup benchmarks for the Topaz layer. It is called by
# benchmarks.sh.

# bench(): Helper function for running Startup benchmarks.
# Arguments:
#     $1         Module to run.
#     $2         Label for benchmark.

bench() {
    MODULE=$1
    BENCHMARK=$2
    COMMAND="fuchsia-pkg://fuchsia.com/basemgr#meta/basemgr.cmx "`
      `"--test --enable_presenter --account_provider=fuchsia-pkg://fuchsia.com/dev_token_manager#meta/dev_token_manager.cmx "`
      `"--base_shell=fuchsia-pkg://fuchsia.com/dev_base_shell#meta/dev_base_shell.cmx --base_shell_args=--test_timeout_ms=60000 "`
      `"--session_shell=fuchsia-pkg://fuchsia.com/dev_session_shell#meta/dev_session_shell.cmx --session_shell_args=--root_module=${MODULE} --story_shell=fuchsia-pkg://fuchsia.com/mondrian#meta/mondrian.cmx"

    runbench_exec "${OUT_DIR}/${BENCHMARK}.json"                           \
      "/pkgfs/packages/startup_benchmarks/0/bin/run_startup_benchmark.sh"  \
      --out_dir "${OUT_DIR}"                                               \
      --out_file "${OUT_DIR}/${BENCHMARK}.json"                            \
      --benchmark_label "${BENCHMARK}"                                     \
      --flutter_app_name "${MODULE}"                                       \
      --cmd "${COMMAND}"
}

# dashboard
bench "dashboard" "fuchsia.startup.dashboard"

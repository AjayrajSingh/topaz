#!/boot/bin/sh
#
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This script runs all benchmarks for the Topaz layer.
#
# For usage, see runbench_read_arguments in runbenchmarks.sh.

# Import the runbenchmarks library.
. /pkgfs/packages/runbenchmarks/0/data/runbenchmarks.sh

runbench_read_arguments "$@"

# Run benchmarks
if `/pkgfs/packages/run/0/bin/run vulkan_is_supported`; then
  # Run these benchmarks in the current shell environment, because they write
  # to (hidden) global state used by runbench_finish.
  . /pkgfs/packages/startup_benchmarks/0/bin/startup_benchmarks.sh "$@"
  . /pkgfs/packages/topaz_benchmarks/0/bin/gfx_benchmarks.sh "$@"
else
  echo "Vulkan not supported; graphics tests skipped."
fi

# Exit with a code indicating whether any errors occurred.
runbench_finish "${OUT_DIR}"

#!/boot/bin/sh
#
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This script launches the topaz benchmarks binary, which runs all benchmarks
# for the Topaz layer.

/pkgfs/packages/topaz_benchmarks/0/bin/topaz_benchmarks "$@"

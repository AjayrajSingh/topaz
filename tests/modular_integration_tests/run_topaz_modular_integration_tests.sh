#!/boot/bin/sh
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -o errexit

# In the event of previous failures from other scripts or other components using
# the GPU, ensure that all components using the display have been shut down.
killall basemgr* || true
killall root_presenter* || true
killall scenic* || true

run_integration_tests --test_file=/pkgfs/packages/topaz_modular_integration_tests/0/data/topaz_modular_integration_tests.json "$@"

#!/boot/bin/sh
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -o errexit

# The test starts its own basemgr.
killall basemgr* || true
# The test uses set_root_view which won't work if these are already running.
killall root_presenter* || true
killall scenic* || true

run_integration_tests --test_file=/pkgfs/packages/flutter_screencap_test/0/data/flutter_screencap_test.json "$@"

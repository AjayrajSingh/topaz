#!/boot/bin/sh
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -o errexit

run_integration_tests --test_file=/pkgfs/packages/flutter_screencap_test/0/data/flutter_screencap_test.json "$@"

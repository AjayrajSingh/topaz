#!/bin/bash
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This creates the files lib/before-during.dart from lib/before.dart and
# lib/after-during from lib/after.dart.

set -eu

cd "$( dirname "${BASH_SOURCE[0]}" )"

sed -e 's/extends before/extends during/' lib/before.dart > lib/before-during.dart
sed -e 's/extends after/extends during/' lib/after.dart > lib/after-during.dart
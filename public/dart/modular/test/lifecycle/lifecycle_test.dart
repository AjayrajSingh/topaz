// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/lifecycle/lifecycle.dart';

void main() {
  test('factory should return same instance', () {
    expect(Lifecycle(), Lifecycle());
  });
}

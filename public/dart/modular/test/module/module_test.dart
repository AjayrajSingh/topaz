// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/module/module.dart';

void main() {
  group('module tests', () {
    test('factory returns same instance', () {
      expect(Module(), Module());
    });
  });
}

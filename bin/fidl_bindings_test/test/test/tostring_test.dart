// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:fidl_fidl_examples_bindingstest/fidl_async.dart';

void main() {
  print('toString-test');
  group('bits', () {
    test('no bit', () {
      expect(ExampleBits.$none.toString(), equals(r'ExampleBits.$none'));
    });
    test('single bit', () {
      expect(ExampleBits.memberC.toString(), equals(r'ExampleBits.memberC'));
    });
    test('multiple bits', () {
      expect(
        (ExampleBits.memberC | ExampleBits.memberA).toString(),
        equals(r'ExampleBits.memberA | ExampleBits.memberC'));
    });
  });
}

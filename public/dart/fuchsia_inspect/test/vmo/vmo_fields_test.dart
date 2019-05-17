// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fuchsia_inspect/src/vmo/vmo_fields.dart';
import 'package:test/test.dart';

void main() {
  group('BlockType', () {
    test('has 12 types', () {
      expect(BlockType.values, hasLength(12));
    });
    test('has unique names', () {
      var blockNames = Set.of(BlockType.values.map((value) => value.name));
      expect(blockNames, hasLength(BlockType.values.length));
    });
    test('has 1:1 values, correctly ordered.', () {
      for (int i = 0; i < BlockType.values.length; i++) {
        expect(BlockType.values[i].value, i);
      }
    });
  });
}

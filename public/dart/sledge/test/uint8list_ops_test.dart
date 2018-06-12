// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:sledge/src/document/uint8list_ops.dart';
import 'package:test/test.dart';

void main() {
  test('Concatentaion of Uint8Lists', () {
    final l1 = [1, 2], l2 = [3, 4, 5], l3 = [6];
    final uint8lConcat = concatListOfUint8Lists([
      new Uint8List.fromList(l1),
      new Uint8List.fromList(l2),
      new Uint8List.fromList(l3)
    ]);
    expect(uint8lConcat.toList(), equals([1, 2, 3, 4, 5, 6]));
  });

  test('Concatentaion of Uint8Lists #2', () {
    final l1 = [1], l2 = [10], l3 = [3], l4 = [6];
    final uint8lConcat = concatListOfUint8Lists([
      new Uint8List.fromList(l1),
      new Uint8List.fromList(l2),
      new Uint8List.fromList(l3),
      new Uint8List.fromList(l4)
    ]);
    expect(uint8lConcat.toList(), equals([1, 10, 3, 6]));
  });
}

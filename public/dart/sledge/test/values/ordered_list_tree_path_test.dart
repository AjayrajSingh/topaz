// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/ordered_list_tree_path.dart';
import 'package:test/test.dart';

class IncrementalTime {
  int _incrementalTime = 0;
  Uint8List get timestamp {
    _incrementalTime += 1;
    return Uint8List(8)..buffer.asByteData().setUint64(0, _incrementalTime);
  }
}

void main() {
  setupLogger();

  test('isDescendant.', () {
    var time = IncrementalTime();
    var root = OrderedListTreePath.root();
    expect(root.isDescendant(root), isFalse);

    // root -
    //      |
    //      - - -> p(v1) - - -> v1

    var v1 = root.getChild(
        ChildType.right, Uint8List.fromList([1]), time.timestamp);
    expect(v1.isDescendant(root), isTrue);
    expect(v1.isDescendant(v1), isFalse);
    expect(root.isDescendant(v1), isFalse);

    // root -
    //      |
    //      -----> p(v1) -----> v1
    //      |
    //      - - -> p(v2) - - -> v2

    var v2 = root.getChild(
        ChildType.right, Uint8List.fromList([2]), time.timestamp);
    expect(v2.isDescendant(root), isTrue);
    expect(v2.isDescendant(v2), isFalse);
    expect(v1.isDescendant(v2), isFalse);
    expect(root.isDescendant(v2), isFalse);

    // root -            - - -> p(v3) - - -> v3
    //      |            |
    //      -----> p(v1) -----> v1
    //      |
    //      -----> p(v2) -----> v2

    var v3 = v1.getChild(
        ChildType.left, Uint8List.fromList([0, 1, 2]), time.timestamp);
    expect(v3.isDescendant(root), isTrue);
    expect(v3.isDescendant(v1), isTrue);
    expect(v3.isDescendant(v2), isFalse);
    expect(v3.isDescendant(v3), isFalse);

    expect(root.isDescendant(v3), isFalse);
    expect(v1.isDescendant(v3), isFalse);
    expect(v2.isDescendant(v3), isFalse);
  });
}

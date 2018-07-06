// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:sledge/src/document/values/ordered_list_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

class TestOrderedListValue<E> extends OrderedListValue<E> {
  TestOrderedListValue([Uint8List id])
      : super(id ?? new Uint8List.fromList([1])) {
    observer = new DummyValueObserver();
  }
}

void main() {
  Equality eq = const ListEquality();

  test('Add to end of list and check content.', () {
    var s = new TestOrderedListValue<int>();
    expect(eq.equals(s.toList(), <int>[]), isTrue);
    s.insert(0, 1);
    expect(eq.equals(s.toList(), <int>[1]), isTrue);
    s.insert(1, 2);
    expect(eq.equals(s.toList(), <int>[1, 2]), isTrue);
    s.insert(2, 3);
    expect(eq.equals(s.toList(), <int>[1, 2, 3]), isTrue);
  });

  test('Insert into random positions of list and check content.', () {
    var s = new TestOrderedListValue<int>();
    expect(eq.equals(s.toList(), <int>[]), isTrue);
    s.insert(0, 1);
    expect(eq.equals(s.toList(), <int>[1]), isTrue);
    s.insert(1, 2);
    expect(eq.equals(s.toList(), <int>[1, 2]), isTrue);
    s.insert(1, 3);
    expect(eq.equals(s.toList(), <int>[1, 3, 2]), isTrue);
    s.insert(0, 4);
    expect(eq.equals(s.toList(), <int>[4, 1, 3, 2]), isTrue);
    s.insert(1, 5);
    expect(eq.equals(s.toList(), <int>[4, 5, 1, 3, 2]), isTrue);
  });

  test('Insert into random positions, delete from list and check content.', () {
    var s = new TestOrderedListValue<int>();
    expect(eq.equals(s.toList(), <int>[]), isTrue);
    s.insert(0, 1);
    expect(eq.equals(s.toList(), <int>[1]), isTrue);
    s.insert(1, 2);
    expect(eq.equals(s.toList(), <int>[1, 2]), isTrue);
    s.insert(1, 3);
    expect(eq.equals(s.toList(), <int>[1, 3, 2]), isTrue);
    expect(s.removeAt(2), equals(2));
    expect(eq.equals(s.toList(), <int>[1, 3]), isTrue);
    expect(s.removeAt(0), equals(1));
    expect(eq.equals(s.toList(), <int>[3]), isTrue);
    s.insert(1, 2);
    expect(eq.equals(s.toList(), <int>[3, 2]), isTrue);
    s.insert(1, 4);
    expect(eq.equals(s.toList(), <int>[3, 4, 2]), isTrue);
    expect(s.removeAt(0), equals(3));
    expect(eq.equals(s.toList(), <int>[4, 2]), isTrue);
  });

  test('Simple operations.', () {
    var s = new TestOrderedListValue<int>();
    expect(eq.equals(s.toList(), <int>[]), isTrue);
    s.insert(0, 1);
    expect(s[0], equals(1));
    s.insert(1, 2);
    expect(s[0], equals(1));
    expect(s[1], equals(2));
    s.insert(1, 3);
    expect(s[0], equals(1));
    expect(s[1], equals(3));
    expect(s[2], equals(2));
    expect(s.removeAt(0), equals(1));
    expect(s[0], equals(3));
    expect(s[1], equals(2));
  });

  group('Exceptions', () {
    test('Insert out of range', () {
      var s = new TestOrderedListValue<int>();
      expect(() => s.insert(1, 1), throwsRangeError);
      s.insert(0, 1);
      expect(() => s.insert(2, 0), throwsRangeError);
      expect(() => s.insert(-1, 0), throwsRangeError);
    });

    test('[] out of range', () {
      var s = new TestOrderedListValue<int>();
      expect(() => s[1], throwsRangeError);
      expect(() => s[4], throwsRangeError);
      s.insert(0, 1);
      expect(() => s[2], throwsRangeError);
      expect(() => s[-1], throwsRangeError);
    });

    test('Remove out of range', () {
      var s = new TestOrderedListValue<int>();
      expect(() => s.removeAt(0), throwsRangeError);
      expect(() => s.removeAt(1), throwsRangeError);
      s.insert(0, 1);
      expect(() => s.removeAt(-1), throwsRangeError);
      expect(() => s.removeAt(1), throwsRangeError);
      expect(s.removeAt(0), 1);
    });
  });

  test('Insert into random positions of list and check content. Large test.',
      () {
    final random = new Random(1);
    var s = new TestOrderedListValue<int>();
    var list = <int>[];
    expect(s.toList(), equals(<int>[]));
    for (int value = 0; value < 100; value++) {
      int pos = random.nextInt(list.length + 1);
      s.insert(pos, value);
      list.insert(pos, value);
      expect(s.toList(), equals(list));
    }
  });

  test('Complex example of inserting in the list.', () {
    var s = new TestOrderedListValue<int>()
      ..insert(0, 0)
      ..insert(0, 1)
      ..insert(1, 2)
      ..insert(0, 3)
      ..insert(1, 4)
      ..insert(4, 5)
      ..insert(2, 6)
      ..insert(0, 7)
      ..insert(7, 8)
      ..insert(6, 9)
      ..insert(10, 10);
    expect(s.toList(), equals([7, 3, 4, 6, 1, 2, 9, 5, 8, 0, 10]));
  });
}

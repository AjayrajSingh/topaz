// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:sledge/src/document/values/ordered_list_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

class TestOrderedListValue<E> extends OrderedListValue<E> {
  TestOrderedListValue([Uint8List id])
      : super(id ?? new Uint8List.fromList([1])) {
    this.observer = new DummyValueObserver();
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

  test('Add to random positions of list and check content.', () {
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

  test('Add to random positions, delete from list and check content.', () {
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
}

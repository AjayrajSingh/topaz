// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/src/document/leaf_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

// TODO: make tests generic.
// typedef SetCreator = Set<K, V> Function<K, V>();
// issue: template arguments of generic function have dynamic runtime type, so
// Converter factory constructor throws exception.
typedef SetCreator = Set<int> Function();

/// Generic class, to test if [TestingSet] correctly implements Set API.
class SetApiTester<TestingSet extends Set> {
  final SetCreator _setCreator;

  SetApiTester(this._setCreator);

  /// Tests Set API implementation.
  void testApi() {
    test('iterator', () {
      final s = _setCreator()..addAll([1, 3, 4]);
      final it = s.iterator;
      final list = <int>[];
      while (it.moveNext()) {
        list.add(it.current);
      }
      expect(list, equals([1, 3, 4]));
    });

    test('first', () {
      final s = _setCreator();
      expect(() => s.first, throwsStateError);
      s.add(1);
      expect(s.first, equals(1));
    });

    test('hashCode', () {
      // ignore: unused_local_variable
      final s = _setCreator().hashCode;
    });

    test('isEmpty', () {
      final s = _setCreator();
      expect(s.isEmpty, isTrue);
      s.add(1);
      expect(s.isEmpty, isFalse);
    });

    test('isNotEmpty', () {
      final s = _setCreator();
      expect(s.isNotEmpty, isFalse);
      s.add(1);
      expect(s.isNotEmpty, isTrue);
    });

    test('last', () {
      final s = _setCreator();
      expect(() => s.last, throwsStateError);
      s.add(1);
      expect(s.last, equals(1));
      s.add(2);
      expect(s.last, isNot(equals(s.first)));
    });

    test('length', () {
      final s = _setCreator();
      expect(s.length, equals(0));
      s..add(0)..add(2)..add(4)..add(4);
      expect(s.length, equals(3));
    });

    test('single', () {
      final s = _setCreator();
      expect(() => s.single, throwsStateError);
      s.add(1);
      expect(s.single, equals(1));
      s.add(2);
      expect(() => s.single, throwsStateError);
    });

    test('operator ==', () {
      final s = _setCreator();
      expect(s == s, isTrue);
      final otherStorage = _setCreator();
      expect(s == otherStorage, isFalse);
    });

    test('add()', () {
      final s = _setCreator();
      expect(s.add(1), isTrue);
      expect(s.add(1), isFalse);
      expect(s.add(2), isTrue);
      expect(s.contains(1), isTrue);
      expect(s.contains(2), isTrue);
    });

    test('addAll()', () {
      final s = _setCreator()..add(0)..add(2)..add(4);
      final other = _setCreator()..add(0)..add(1);
      s.addAll(other);

      expect(s.toList()..sort(), equals([0, 1, 2, 4]));
    });

    test('clear()', () {
      final s = _setCreator()
        ..add(0)
        ..add(2)
        ..add(4)
        ..clear();
      expect(s.isEmpty, isTrue);
    });

    test('contains()', () {
      final s = _setCreator();
      expect(s.contains(0), isFalse);
      expect(s.contains(1), isFalse);
      s.add(0);
      expect(s.contains(0), isTrue);
      expect(s.contains(1), isFalse);
    });

    test('containsAll()', () {
      final s = _setCreator();
      expect(s.containsAll([]), isTrue);
      expect(s.containsAll([0, 1]), isFalse);
      s.add(0);
      expect(s.containsAll([0, 1]), isFalse);
      expect(s.containsAll([0, 0]), isTrue);
      s.add(1);
      expect(s.containsAll([0, 1]), isTrue);
      expect(s.containsAll([0, 2]), isFalse);
      expect(s.containsAll([1]), isTrue);
    });

    test('difference()', () {
      final s = _setCreator()..addAll([1, 2, 3]);
      final other = _setCreator()..addAll([2, 4]);
      final diff = s.difference(other);
      expect(diff.length, equals(2));
      expect(diff.containsAll([1, 3]), isTrue);
    });

    test('intersection()', () {
      final s = _setCreator()..addAll([1, 2, 3]);
      final other = _setCreator()..addAll([2, 3, 4]);
      final inter = s.intersection(other);
      expect(inter.length, equals(2));
      expect(inter.containsAll([2, 3]), isTrue);
    });

    test('lookup()', () {
      final s = _setCreator()..addAll([1, 2, 3]);
      expect(s.lookup(0), equals(null));
      expect(s.lookup(1), equals(1));
      expect(s.lookup(2), equals(2));
      expect(s.lookup(3), equals(3));
    });

    test('remove()', () {
      final s = _setCreator()..addAll([1, 2, 3]);
      expect(s.remove(1), isTrue);
      expect(s.toList()..sort(), equals([2, 3]));
      expect(s.remove(3), isTrue);
      expect(s.toList()..sort(), equals([2]));
      expect(s.remove(1), isFalse);
      expect(s.remove(3), isFalse);
      expect(s.remove(2), isTrue);
      expect(s.isEmpty, isTrue);
    });

    test('removeAll()', () {
      final s = _setCreator()
        ..addAll([1, 2, 3])
        ..removeAll([1, 3]);
      expect(s.toList(), equals([2]));
      s
        ..addAll([1, 2, 3, 4, 5])
        ..removeAll([2, 4, 6, 5, 10, 20]);
      expect(s.toList()..sort(), equals([1, 3]));
      s.removeAll([1, 2, 3, 4, 5]);
      expect(s.isEmpty, true);
    });

    test('removeWhere()', () {
      final s = _setCreator()
        ..addAll([1, 2, 3, 4, 5, 6])
        ..removeWhere((x) => x.isEven);
      expect(s.toList()..sort(), equals([1, 3, 5]));
      s
        ..addAll([1, 2, 3, 4, 5, 6])
        ..removeWhere((x) => true);
      expect(s.isEmpty, isTrue);
    });

    test('retainWhere()', () {
      final s = _setCreator()
        ..addAll([1, 2, 3, 4, 5, 6])
        ..retainWhere((x) => x.isEven);
      expect(s.toList()..sort(), equals([2, 4, 6]));
      s
        ..addAll([1, 2, 3, 4, 5, 6])
        ..retainWhere((x) => false);
      expect(s.isEmpty, isTrue);
    });

    test('toSet()', () {
      final s = _setCreator()
        ..addAll([1, 2, 3, 4, 5])
        ..remove(2);
      expect(s.toSet().toList()..sort(), equals([1, 3, 4, 5]));
    });

    // TODO: add tests for inherited methods.
  }

  void testObserver() {
    test('Observer calls.', () {
      final s = _setCreator();
      final observer = DummyValueObserver();
      expect(s, const TypeMatcher<LeafValue>());
      dynamic leafValue = s;
      leafValue.observer = observer; // ignore: cascade_invocations
      expect(s.contains(0), equals(false));
      observer.expectNotChanged();

      // Check that each modification method calls observer.valueWasChanged():
      s.add(2);
      observer
        ..expectChanged()
        ..reset();

      s.addAll([1, 2, 3, 4, 5]);
      observer
        ..expectChanged()
        ..reset();

      s.remove(1);
      observer
        ..expectChanged()
        ..reset();

      s.removeAll([1, 2]);
      observer
        ..expectChanged()
        ..reset();

      s.removeWhere((x) => x.isEven);
      observer
        ..expectChanged()
        ..reset();

      s.retainWhere((x) => x == 3);
      observer
        ..expectChanged()
        ..reset();

      s.clear();
      observer
        ..expectChanged()
        ..reset();
    });
  }
}

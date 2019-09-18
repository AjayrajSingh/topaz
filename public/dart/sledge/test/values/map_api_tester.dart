// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

// TODO: make tests generic.
// typedef MapCreator = Map<K, V> Function<K, V>();
// issue: template arguments of generic function have dynamic runtime type, so
// Converter factory constructor throws exception.
typedef MapCreator = Map<int, int> Function();

/// Generic class, to test if [TestingMap] correctly implements Map API.
class MapApiTester<TestingMap extends Map> {
  final MapCreator _mapCreator;

  MapApiTester(this._mapCreator);

  /// Tests Map API implementation.
  void testApi() {
    test('hashCode', () {
      // ignore: unused_local_variable
      final map = _mapCreator().hashCode;
    });

    test('isEmpty', () {
      final map = _mapCreator();
      expect(map.isEmpty, isTrue);
      map[0] = 1;
      expect(map.isEmpty, isFalse);
    });

    test('isNotEmpty', () {
      final map = _mapCreator();
      expect(map.isNotEmpty, isFalse);
      map[0] = 1;
      expect(map.isNotEmpty, isTrue);
    });

    test('keys', () {
      final map = _mapCreator();
      expect(map.keys.toList(), equals([]));
      map[0] = 1;
      map[2] = 1;
      map[4] = 1;
      map[4] = 2;
      expect(map.keys.toList()..sort(), equals([0, 2, 4]));
    });

    test('length', () {
      final map = _mapCreator();
      expect(map.length, equals(0));
      map[0] = 1;
      map[2] = 1;
      map[4] = 1;
      map[4] = 2;
      expect(map.length, equals(3));
    });

    test('values', () {
      final map = _mapCreator();
      expect(map.values.toList(), equals([]));
      map[0] = 1;
      map[2] = 1;
      map[4] = 1;
      map[4] = 2;
      expect(map.values.toList()..sort(), equals([1, 1, 2]));
    });

    test('operator ==', () {
      final map = _mapCreator();
      expect(map == map, isTrue);
      final otherStorage = _mapCreator();
      expect(map == otherStorage, isFalse);
    });

    test('operator []', () {
      final map = _mapCreator();
      expect(map[0], isNull);
      map[0] = 1;
      map[2] = 1;
      map[4] = 1;
      map[4] = 2;
      expect(map[0], equals(1));
      expect(map[2], equals(1));
      expect(map[4], equals(2));
      expect(map[3], isNull);
    });

    test('addAll()', () {
      final map = _mapCreator();
      map[0] = 1;
      map[2] = 1;
      map[4] = 2;
      final other = _mapCreator();
      other[0] = 2;
      other[1] = 1;
      other[3] = 4;
      map.addAll(other);

      expect(map.keys.toList()..sort(), equals([0, 1, 2, 3, 4]));
      expect(map[0], equals(2));
      expect(map[1], equals(1));
      expect(map[2], equals(1));
      expect(map[3], equals(4));
      expect(map[4], equals(2));
    });

    test('clear()', () {
      final map = _mapCreator();
      map[0] = 1;
      map[2] = 1;
      map[4] = 2;
      map.clear();
      expect(map.keys.toList().isEmpty, isTrue);
    });

    test('containsKey()', () {
      final map = _mapCreator();
      expect(map.containsKey(0), isFalse);
      expect(map.containsKey(1), isFalse);
      map[0] = 1;
      expect(map.containsKey(0), isTrue);
      expect(map.containsKey(1), isFalse);
    });

    test('containsValue()', () {
      final map = _mapCreator();
      expect(map.containsValue(1), isFalse);
      map[0] = 1;
      expect(map.containsValue(1), isTrue);
      map[0] = 2;
      expect(map.containsValue(1), isFalse);
      expect(map.containsValue(2), isTrue);
    });

    test('forEach()', () {
      final list = <int>[];
      final map = _mapCreator();
      map[0] = 1;
      map[2] = 1;
      map[4] = 2;
      map.forEach((key, value) => list.add(key));
      expect(list..sort(), equals([0, 2, 4]));
    });

    test('putIfAbsent()', () {
      final map = _mapCreator();
      expect(map.putIfAbsent(0, () => 1), equals(1));
      expect(map.putIfAbsent(0, () => 2), equals(1));
      expect(map.putIfAbsent(1, () => 2), equals(2));
    });

    test('toString()', () {
      final map = _mapCreator();
      map[0] = 1;
      expect(map.toString(), equals('{0: 1}'));
    });
  }

  void testObserver() {
    test('Observer calls.', () {
      final dynamic map = _mapCreator();
      final observer = DummyValueObserver();
      map.observer = observer;
      expect(map.containsKey(0), equals(false));
      observer.expectNotChanged();

      // Check that each modification method calls observer.valueWasChanged():
      map[0] = 1;
      observer
        ..expectChanged()
        ..reset();
      expect(map[0], equals(1));
      observer.expectNotChanged();

      map.putIfAbsent(2, () => 1);
      observer
        ..expectChanged()
        ..reset();

      map.remove(0);
      observer
        ..expectChanged()
        ..reset();

      map.addAll({0: 1, 2: 4, -1: 0});
      observer
        ..expectChanged()
        ..reset();

      map.clear();
      observer
        ..expectChanged()
        ..reset();
    });
  }
}

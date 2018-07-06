// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show Random;

import 'package:test/test.dart';

// TODO: make tests generic.
// typedef ListCreator = List<K, V> Function<K, V>();
// issue: template arguments of generic function have dynamic runtime type, so
// Converter factory constructor throws exception.
typedef ListCreator = List<int> Function();

/// Generic class, to test if [TestingList] correctly implements List API.
class ListApiTester<TestingList extends List> {
  ListCreator _listCreator;

  ListApiTester(this._listCreator);

  /// Tests List API implementation.
  void testApi() {
    test('length', () {
      final list = _listCreator();
      expect(list.length, equals(0));
      list.add(0);
      expect(list.length, equals(1));
      list.insert(0, 1);
      expect(list.length, equals(2));
      list.removeAt(0);
      expect(list.length, equals(1));
    });

    test('reversed', () {
      final list = _listCreator();
      expect(list.toList(), equals([]));
      list..add(0)..add(2)..add(1)..add(3);
      expect(list.toList(), equals([0, 2, 1, 3]));
      expect(list.reversed.toList(), equals([3, 1, 2, 0]));
    });

    test('first', () {
      final list = _listCreator();
      expect(() => list.first, throwsStateError);
      list.add(2);
      expect(list.first, equals(2));
      list.insert(0, 4);
      expect(list.first, equals(4));
      list.add(3);
      expect(list.first, equals(4));
    });

    test('hashCode', () {
      _listCreator().hashCode;
    });

    test('isEmpty', () {
      final list = _listCreator();
      expect(list.isEmpty, isTrue);
      list.insert(0, 1);
      expect(list.isEmpty, isFalse);
      list.removeAt(0);
      expect(list.isEmpty, isTrue);
    });

    test('isNotEmpty', () {
      final list = _listCreator();
      expect(list.isNotEmpty, isFalse);
      list.insert(0, 1);
      expect(list.isNotEmpty, isTrue);
    });

    test('last', () {
      final list = _listCreator();
      expect(() => list.last, throwsStateError);
      list.add(2);
      expect(list.last, equals(2));
      list.insert(0, 4);
      expect(list.last, equals(2));
      list.add(3);
      expect(list.last, equals(3));
    });

    test('single', () {
      final list = _listCreator();
      expect(() => list.single, throwsStateError);
      list.add(2);
      expect(list.single, equals(2));
      list.add(3);
      expect(() => list.single, throwsStateError);
      list.removeAt(0);
      expect(list.single, equals(3));
    });

    test('operator []', () {
      final list = _listCreator();
      expect(() => list[0], throwsRangeError);
      list.add(1);
      expect(list[0], equals(1));
      expect(() => list[1], throwsRangeError);
      expect(() => list[-1], throwsRangeError);
      list.add(2);
      expect(list[0], equals(1));
      expect(list[1], equals(2));
    });

    test('operator []=', () {
      final list = _listCreator();
      expect(() => list[0] = 1, throwsRangeError);
      list.add(2);
      list[0] = 3;
      expect(list[0], equals(3));
      expect(() => list[1] = 2, throwsRangeError);
      expect(() => list[2] = 2, throwsRangeError);
      expect(() => list[-1] = 2, throwsRangeError);
      list.add(4);
      list[0] = 1;
      list[1] = -1;
      expect(list, equals([1, -1]));
    });

    test('add()', () {
      final list = _listCreator()..add(2)..add(1)..add(4);
      expect(list, equals([2, 1, 4]));
    });

    test('addAll()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3])
        ..addAll([4])
        ..addAll([5, 6, 7]);
      expect(list, equals([1, 2, 3, 4, 5, 6, 7]));
    });

    test('asMap()', () {
      final list = _listCreator()..addAll([1, 2, 4, 3]);
      final map = list.asMap();
      expect(map[0], equals(1));
      expect(map[1], equals(2));
      expect(map[2], equals(4));
      expect(map[3], equals(3));
      expect(map.length, equals(4));
    });

    test('clear()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4])
        ..clear();
      expect(list, equals([]));
      list.addAll([1, 2]);
      expect(list, equals([1, 2]));
    });

    test('fillRange()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 5, 6])
        ..fillRange(2, 4, -1);
      expect(list, equals([1, 2, -1, -1, 5, 6]));
      expect(() => list.fillRange(-1, 2, 2), throwsRangeError);
      expect(() => list.fillRange(3, 7, 2), throwsRangeError);
      list.fillRange(3, 6, 5);
      expect(list, equals([1, 2, -1, 5, 5, 5]));
      list.fillRange(0, 6, 3);
      expect(list, equals([3, 3, 3, 3, 3, 3]));
    });

    test('getRange()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 5, 6]);
      expect(() => list.getRange(4, 7), throwsRangeError);
      expect(list.getRange(2, 4).toList(), equals([3, 4]));
      expect(list.getRange(0, 6).toList(), equals([1, 2, 3, 4, 5, 6]));
    });

    test('indexOf()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list.indexOf(2), 1);
      expect(list.indexOf(4), 3);
      expect(list.indexOf(2, 3), 5);
      expect(list.indexOf(4, 4), -1);
      expect(list.indexOf(5), -1);
    });

    test('insert()', () {
      final list = _listCreator();
      expect(() => list.insert(-1, 0), throwsRangeError);
      expect(() => list.insert(1, 0), throwsRangeError);
      list..insert(0, 5)..insert(1, 4)..insert(0, 3);
      expect(list, equals([3, 5, 4]));
      expect(() => list.insert(4, 1), throwsRangeError);
    });

    test('insertAll()', () {
      final list = _listCreator();
      expect(() => list.insertAll(-1, []), throwsRangeError);
      expect(() => list.insertAll(1, []), throwsRangeError);
      list.insertAll(0, [1, 3, 4, 2]);
      expect(list, equals(<int>[]..insertAll(0, [1, 3, 4, 2])));
      list.insertAll(1, [1, 2]);
      expect(list, equals([1, 1, 2, 3, 4, 2]));
    });

    test('lastIndexOf()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list.lastIndexOf(2), 5);
      expect(list.lastIndexOf(4), 3);
      expect(list.lastIndexOf(2, 3), 1);
      expect(list.lastIndexOf(4, 4), 3);
      expect(list.lastIndexOf(4, 4), 3);
      expect(list.lastIndexOf(5), -1);
    });

    test('remove()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list.remove(2), true);
      expect(list.remove(5), false);
      expect(list, equals([1, 3, 4, 1, 2, 3]));
      expect(list.remove(2), true);
      expect(list, equals([1, 3, 4, 1, 3]));
      expect(list.remove(2), false);
      expect(list.remove(4), true);
      expect(list, equals([1, 3, 1, 3]));
    });

    test('removeAt()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list.removeAt(2), equals(3));
      expect(list, equals([1, 2, 4, 1, 2, 3]));
      expect(list.removeAt(2), equals(4));
      expect(list, equals([1, 2, 1, 2, 3]));
      expect(list.removeAt(4), equals(3));
      expect(list, equals([1, 2, 1, 2]));
      expect(() => list.removeAt(-1), throwsRangeError);
      expect(() => list.removeAt(4), throwsRangeError);
    });

    test('removeLast()', () {
      final list = _listCreator()..addAll([1, 2, 3]);
      expect(list.removeLast(), equals(3));
      expect(list.removeLast(), equals(2));
      expect(list.removeLast(), equals(1));
      expect(list.removeLast, throwsRangeError);
      expect(list, equals([]));
    });

    test('removeRange()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(() => list.removeRange(4, 8), throwsRangeError);
      expect(() => list.removeRange(-1, 2), throwsRangeError);
      expect(() => list.removeRange(4, 2), throwsRangeError);
      list.removeRange(2, 4);
      expect(list, equals([1, 2, 1, 2, 3]));
      list.removeRange(3, 4);
      expect(list, equals([1, 2, 1, 3]));
      list.removeRange(0, 4);
      expect(list, equals([]));
    });

    test('removeWhere()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..removeWhere((int x) => x.isEven);
      expect(list, equals([1, 3, 1, 3]));
    });

    test('replaceRange()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..replaceRange(6, 7, [8, 9, 10]);
      expect(list, equals([1, 2, 3, 4, 1, 2, 8, 9, 10]));
      expect(() => list.replaceRange(3, 2, [1, 2]), throwsRangeError);
      list.replaceRange(0, 9, [1, 2]);
      expect(list, equals([1, 2]));
    });

    test('retainWhere()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..retainWhere((int x) => x.isEven);
      expect(list, equals([2, 4, 2]));
    });

    test('setAll()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..setAll(3, [1, 2, 3]);
      expect(list, equals([1, 2, 3, 1, 2, 3, 3]));
      list.setAll(6, [1]);
      expect(list, equals([1, 2, 3, 1, 2, 3, 1]));
      expect(() => list.setAll(6, [1, 1, 1, 1]), throwsRangeError);
      expect(() => list.setAll(10, [1]), throwsRangeError);
    });

    test('setRange()', () {
      final list = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..setRange(3, 5, [5, 6, 7]);
      expect(list, equals([1, 2, 3, 5, 6, 2, 3]));
      expect(() => list.setRange(2, 6, [8], 2), throwsStateError);
      list.setRange(2, 6, [9, 9, 9, 9, 9], 1);
      expect(list, equals([1, 2, 9, 9, 9, 9, 3]));
      list.setRange(2, 3, [7, 7, 7, 7]);
      expect(list, equals([1, 2, 7, 9, 9, 9, 3]));
      expect(() => list.setRange(5, 3, [1, 2]), throwsRangeError);
    });

    test('shuffle()', () {
      final list1 = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..shuffle(new Random(1));
      final list2 = _listCreator()
        ..addAll([1, 2, 3, 4, 1, 2, 3])
        ..shuffle(new Random(2));
      expect(list1.toList()..sort(), equals([1, 1, 2, 2, 3, 3, 4]));
      expect(list1.toList(), isNot(equals(list2.toList())));
    });

    test('sort()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list..sort(), equals([1, 1, 2, 2, 3, 3, 4]));
      expect(
          list..sort((int a, int b) => b - a), equals([4, 3, 3, 2, 2, 1, 1]));
    });

    test('sublist()', () {
      final list = _listCreator()..addAll([1, 2, 3, 4, 1, 2, 3]);
      expect(list.sublist(3), equals([4, 1, 2, 3]));
      expect(list.sublist(3, 5), equals([4, 1]));
      expect(() => list.sublist(4, 2), throwsRangeError);
    });

    // TODO: add tests for inherited methods.

    test('toString()', () {
      final list = _listCreator()..add(2)..add(0);
      expect(list.toString(), equals('[2, 0]'));
    });
  }
}

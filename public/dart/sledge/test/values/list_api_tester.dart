// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show Random;

import 'package:sledge/src/document/leaf_value.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

// methods: removeWhere, retainWhere, sort, shuffle are not tested.

/// Generic class, to test if [TestingList] correctly implements List API.
class ListApiTester<TestingList extends List, E> {
  final List<E> Function() _newList;
  final E Function(int id) _newElement;

  ListApiTester(this._newList, this._newElement);

  /// Tests List API implementation.
  void testApi() {
    test('length', () {
      final list = _newList();
      expect(list.length, equals(0));
      list.add(_newElement(0));
      expect(list.length, equals(1));
      list.insert(0, _newElement(1));
      expect(list.length, equals(2));
      list.removeAt(0);
      expect(list.length, equals(1));
    });

    test('reversed', () {
      final list = _newList();
      expect(list.toList(), equals([]));
      list
        ..add(_newElement(0))
        ..add(_newElement(2))
        ..add(_newElement(1))
        ..add(_newElement(3));
      expect(
          list.toList(),
          equals([
            _newElement(0),
            _newElement(2),
            _newElement(1),
            _newElement(3)
          ]));
      expect(
          list.reversed.toList(),
          equals([
            _newElement(3),
            _newElement(1),
            _newElement(2),
            _newElement(0)
          ]));
    });

    test('first', () {
      final list = _newList();
      expect(() => list.first, throwsStateError);
      list.add(_newElement(2));
      expect(list.first, equals(_newElement(2)));
      list.insert(0, _newElement(4));
      expect(list.first, equals(_newElement(4)));
      list.add(_newElement(3));
      expect(list.first, equals(_newElement(4)));
    });

    test('hashCode', () {
      _newList().hashCode;
    });

    test('isEmpty', () {
      final list = _newList();
      expect(list.isEmpty, isTrue);
      list.insert(0, _newElement(1));
      expect(list.isEmpty, isFalse);
      list.removeAt(0);
      expect(list.isEmpty, isTrue);
    });

    test('isNotEmpty', () {
      final list = _newList();
      expect(list.isNotEmpty, isFalse);
      list.insert(0, _newElement(1));
      expect(list.isNotEmpty, isTrue);
    });

    test('last', () {
      final list = _newList();
      expect(() => list.last, throwsStateError);
      list.add(_newElement(2));
      expect(list.last, equals(_newElement(2)));
      list.insert(0, _newElement(4));
      expect(list.last, equals(_newElement(2)));
      list.add(_newElement(3));
      expect(list.last, equals(_newElement(3)));
    });

    test('single', () {
      final list = _newList();
      expect(() => list.single, throwsStateError);
      list.add(_newElement(2));
      expect(list.single, equals(_newElement(2)));
      list.add(_newElement(3));
      expect(() => list.single, throwsStateError);
      list.removeAt(0);
      expect(list.single, equals(_newElement(3)));
    });

    test('operator []', () {
      final list = _newList();
      expect(() => list[0], throwsRangeError);
      list.add(_newElement(1));
      expect(list[0], equals(_newElement(1)));
      expect(() => list[1], throwsRangeError);
      expect(() => list[-1], throwsRangeError);
      list.add(_newElement(2));
      expect(list[0], equals(_newElement(1)));
      expect(list[1], equals(_newElement(2)));
    });

    test('operator []=', () {
      final list = _newList();
      expect(() => list[0] = _newElement(1), throwsRangeError);
      list.add(_newElement(2));
      list[0] = _newElement(3);
      expect(list[0], equals(_newElement(3)));
      expect(() => list[1] = _newElement(2), throwsRangeError);
      expect(() => list[2] = _newElement(2), throwsRangeError);
      expect(() => list[-1] = _newElement(2), throwsRangeError);
      list.add(_newElement(4));
      list[0] = _newElement(1);
      list[1] = _newElement(-1);
      expect(list, equals([_newElement(1), _newElement(-1)]));
    });

    test('add()', () {
      final list = _newList()
        ..add(_newElement(2))
        ..add(_newElement(1))
        ..add(_newElement(4));
      expect(list, equals([_newElement(2), _newElement(1), _newElement(4)]));
    });

    test('addAll()', () {
      final list = _newList()
        ..addAll([_newElement(1), _newElement(2), _newElement(3)])
        ..addAll([_newElement(4)])
        ..addAll([_newElement(5), _newElement(6), _newElement(7)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(4),
            _newElement(5),
            _newElement(6),
            _newElement(7)
          ]));
    });

    test('asMap()', () {
      final list = _newList()
        ..addAll(
            [_newElement(1), _newElement(2), _newElement(4), _newElement(3)]);
      final map = list.asMap();
      expect(map[0], equals(_newElement(1)));
      expect(map[1], equals(_newElement(2)));
      expect(map[2], equals(_newElement(4)));
      expect(map[3], equals(_newElement(3)));
      expect(map.length, equals(4));
    });

    test('clear()', () {
      final list = _newList()
        ..addAll(
            [_newElement(1), _newElement(2), _newElement(3), _newElement(4)])
        ..clear();
      expect(list, equals([]));
      list.addAll([_newElement(1), _newElement(2)]);
      expect(list, equals([_newElement(1), _newElement(2)]));
    });

    test('fillRange()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(5),
          _newElement(6)
        ])
        ..fillRange(2, 4, _newElement(-1));
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(-1),
            _newElement(-1),
            _newElement(5),
            _newElement(6)
          ]));
      expect(() => list.fillRange(-1, 2, _newElement(2)), throwsRangeError);
      expect(() => list.fillRange(3, 7, _newElement(2)), throwsRangeError);
      list.fillRange(3, 6, _newElement(5));
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(-1),
            _newElement(5),
            _newElement(5),
            _newElement(5)
          ]));
      list.fillRange(0, 6, _newElement(3));
      expect(
          list,
          equals([
            _newElement(3),
            _newElement(3),
            _newElement(3),
            _newElement(3),
            _newElement(3),
            _newElement(3)
          ]));
    });

    test('getRange()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(5),
          _newElement(6)
        ]);
      expect(() => list.getRange(4, 7), throwsRangeError);
      expect(list.getRange(2, 4).toList(),
          equals([_newElement(3), _newElement(4)]));
      expect(
          list.getRange(0, 6).toList(),
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(4),
            _newElement(5),
            _newElement(6)
          ]));
    });

    test('indexOf()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(list.indexOf(_newElement(2)), 1);
      expect(list.indexOf(_newElement(4)), 3);
      expect(list.indexOf(_newElement(2), 3), 5);
      expect(list.indexOf(_newElement(4), 4), -1);
      expect(list.indexOf(_newElement(5)), -1);
    });

    test('insert()', () {
      final list = _newList();
      expect(() => list.insert(-1, _newElement(0)), throwsRangeError);
      expect(() => list.insert(1, _newElement(0)), throwsRangeError);
      list
        ..insert(0, _newElement(5))
        ..insert(1, _newElement(4))
        ..insert(0, _newElement(3));
      expect(list, equals([_newElement(3), _newElement(5), _newElement(4)]));
      expect(() => list.insert(4, _newElement(1)), throwsRangeError);
    });

    test('insertAll()', () {
      final list = _newList();
      expect(() => list.insertAll(-1, []), throwsRangeError);
      expect(() => list.insertAll(1, []), throwsRangeError);
      list.insertAll(
          0, [_newElement(1), _newElement(3), _newElement(4), _newElement(2)]);
      expect(
          list,
          equals(<E>[]..insertAll(0, [
              _newElement(1),
              _newElement(3),
              _newElement(4),
              _newElement(2)
            ])));
      list.insertAll(1, [_newElement(1), _newElement(2)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(4),
            _newElement(2)
          ]));
    });

    test('lastIndexOf()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(list.lastIndexOf(_newElement(2)), 5);
      expect(list.lastIndexOf(_newElement(4)), 3);
      expect(list.lastIndexOf(_newElement(2), 3), 1);
      expect(list.lastIndexOf(_newElement(4), 4), 3);
      expect(list.lastIndexOf(_newElement(5)), -1);
    });

    test('remove()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(list.remove(_newElement(2)), true);
      expect(list.remove(_newElement(5)), false);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(3),
            _newElement(4),
            _newElement(1),
            _newElement(2),
            _newElement(3)
          ]));
      expect(list.remove(_newElement(2)), true);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(3),
            _newElement(4),
            _newElement(1),
            _newElement(3)
          ]));
      expect(list.remove(_newElement(2)), false);
      expect(list.remove(_newElement(4)), true);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(3),
            _newElement(1),
            _newElement(3)
          ]));
    });

    test('removeAt()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(list.removeAt(2), equals(_newElement(3)));
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(4),
            _newElement(1),
            _newElement(2),
            _newElement(3)
          ]));
      expect(list.removeAt(2), equals(_newElement(4)));
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(1),
            _newElement(2),
            _newElement(3)
          ]));
      expect(list.removeAt(4), equals(_newElement(3)));
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(1),
            _newElement(2)
          ]));
      expect(() => list.removeAt(-1), throwsRangeError);
      expect(() => list.removeAt(4), throwsRangeError);
    });

    test('removeLast()', () {
      final list = _newList()
        ..addAll([_newElement(1), _newElement(2), _newElement(3)]);
      expect(list.removeLast(), equals(_newElement(3)));
      expect(list.removeLast(), equals(_newElement(2)));
      expect(list.removeLast(), equals(_newElement(1)));
      expect(list.removeLast, throwsRangeError);
      expect(list, equals([]));
    });

    test('removeRange()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(() => list.removeRange(4, 8), throwsRangeError);
      expect(() => list.removeRange(-1, 2), throwsRangeError);
      expect(() => list.removeRange(4, 2), throwsRangeError);
      list.removeRange(2, 4);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(1),
            _newElement(2),
            _newElement(3)
          ]));
      list.removeRange(3, 4);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(1),
            _newElement(3)
          ]));
      list.removeRange(0, 4);
      expect(list, equals([]));
    });

    test('replaceRange()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ])
        ..replaceRange(6, 7, [_newElement(8), _newElement(9), _newElement(10)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(4),
            _newElement(1),
            _newElement(2),
            _newElement(8),
            _newElement(9),
            _newElement(10)
          ]));
      expect(() => list.replaceRange(3, 2, [_newElement(1), _newElement(2)]),
          throwsRangeError);
      list.replaceRange(0, 9, [_newElement(1), _newElement(2)]);
      expect(list, equals([_newElement(1), _newElement(2)]));
    });

    test('setAll()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ])
        ..setAll(3, [_newElement(1), _newElement(2), _newElement(3)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(3)
          ]));
      list.setAll(6, [_newElement(1)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(1)
          ]));
      expect(
          () => list.setAll(6,
              [_newElement(1), _newElement(1), _newElement(1), _newElement(1)]),
          throwsRangeError);
      expect(() => list.setAll(10, [_newElement(1)]), throwsRangeError);
    });

    test('setRange()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ])
        ..setRange(3, 5, [_newElement(5), _newElement(6), _newElement(7)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(3),
            _newElement(5),
            _newElement(6),
            _newElement(2),
            _newElement(3)
          ]));
      expect(() => list.setRange(2, 6, [_newElement(8)], 2), throwsStateError);
      list.setRange(
          2,
          6,
          [
            _newElement(9),
            _newElement(9),
            _newElement(9),
            _newElement(9),
            _newElement(9)
          ],
          1);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(9),
            _newElement(9),
            _newElement(9),
            _newElement(9),
            _newElement(3)
          ]));
      list.setRange(2, 3,
          [_newElement(7), _newElement(7), _newElement(7), _newElement(7)]);
      expect(
          list,
          equals([
            _newElement(1),
            _newElement(2),
            _newElement(7),
            _newElement(9),
            _newElement(9),
            _newElement(9),
            _newElement(3)
          ]));
      expect(() => list.setRange(5, 3, [_newElement(1), _newElement(2)]),
          throwsRangeError);
    });

    test('sublist()', () {
      final list = _newList()
        ..addAll([
          _newElement(1),
          _newElement(2),
          _newElement(3),
          _newElement(4),
          _newElement(1),
          _newElement(2),
          _newElement(3)
        ]);
      expect(
          list.sublist(3),
          equals([
            _newElement(4),
            _newElement(1),
            _newElement(2),
            _newElement(3)
          ]));
      expect(list.sublist(3, 5), equals([_newElement(4), _newElement(1)]));
      expect(() => list.sublist(4, 2), throwsRangeError);
    });

    // TODO: add tests for inherited methods.

    test('toString()', () {
      final list = _newList()..add(_newElement(2))..add(_newElement(0));
      expect(list.toString(), equals('[${_newElement(2)}, ${_newElement(0)}]'));
    });
  }

  void testObserver() {
    test('Observer calls.', () {
      final list = _newList();
      final observer = DummyValueObserver();
      expect(list, const TypeMatcher<LeafValue>());
      dynamic leafValue = list;
      leafValue.observer = observer; // ignore: cascade_invocations
      expect(list.length, equals(0));
      observer.expectNotChanged();

      // Check that each modification method calls observer.valueWasChanged():
      list.add(_newElement(1));
      observer
        ..expectChanged()
        ..reset();

      list.addAll([
        _newElement(3),
        _newElement(2),
        _newElement(1),
        _newElement(5),
        _newElement(5),
        _newElement(5),
        _newElement(5),
        _newElement(5)
      ]);
      observer
        ..expectChanged()
        ..reset();

      list.insert(2, _newElement(5));
      observer
        ..expectChanged()
        ..reset();

      list.insertAll(1, [_newElement(6), _newElement(7)]);
      observer
        ..expectChanged()
        ..reset();

      list.shuffle(Random(1));
      observer
        ..expectChanged()
        ..reset();

      list.remove(_newElement(1));
      observer
        ..expectChanged()
        ..reset();

      list.removeAt(2);
      observer
        ..expectChanged()
        ..reset();

      list.removeLast();
      observer
        ..expectChanged()
        ..reset();

      list.removeRange(1, 2);
      observer
        ..expectChanged()
        ..reset();

      list.replaceRange(0, 2, [_newElement(1), _newElement(2)]);
      observer
        ..expectChanged()
        ..reset();

      list.setAll(0, [_newElement(1), _newElement(2)]);
      observer
        ..expectChanged()
        ..reset();

      list.setRange(0, 2, [_newElement(1), _newElement(2)]);
      observer
        ..expectChanged()
        ..reset();

      list.clear();
      observer
        ..expectChanged()
        ..reset();
    });
  }
}

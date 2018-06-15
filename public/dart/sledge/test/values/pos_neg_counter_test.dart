// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/pos_neg_counter_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

class TestPosNegCounterValue<T extends num> extends PosNegCounterValue<T> {
  TestPosNegCounterValue(int id, [Change init]) : super(id, init) {
    observer = new DummyValueObserver();
  }
}

void main() {
  test('PosNegCounterValue accumulate additions', () {
    var cnt = new TestPosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(1);
    expect(cnt.value, equals(1));
    cnt.add(5);
    expect(cnt.value, equals(6));
    cnt.add(3);
    expect(cnt.value, equals(9));
  });

  test('PosNegCounterValue accumulate subtractions', () {
    var cnt = new TestPosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(-1);
    expect(cnt.value, equals(-1));
    cnt.add(-2);
    expect(cnt.value, equals(-3));
    cnt.add(-3);
    expect(cnt.value, equals(-6));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new TestPosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(-3);
    expect(cnt.value, equals(-3));
    cnt.add(2);
    expect(cnt.value, equals(-1));
    cnt.add(5);
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new TestPosNegCounterValue<double>(1);
    expect(cnt.value, equals(0.0));
    cnt.add(-3.2);
    expect(cnt.value, equals(-3.2));
    cnt.add(2.12);
    expect(cnt.value, equals(-1.08));
    cnt.add(5.0);
    expect(cnt.value, equals(3.92));
  });

  test('PosNegCounterValue construction', () {
    DataConverter conv = new DataConverter<int, int>();
    var cnt = new TestPosNegCounterValue<int>(
        1, conv.serialize(new ConvertedChange<int, int>({2: 4, 3: 3})));
    expect(cnt.value, equals(1));
  });

  test('PosNegCounterValue construction 2', () {
    DataConverter conv = new DataConverter<int, int>();
    var cnt = new TestPosNegCounterValue<int>(
        1,
        conv.serialize(
            new ConvertedChange<int, int>({2: 4, 3: 3, 6: 5, 7: 2})));
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue construction double', () {
    DataConverter conv = new DataConverter<int, double>();
    var cnt = new TestPosNegCounterValue<double>(
        1,
        conv.serialize(new ConvertedChange<int, double>(
            {2: 4.25, 3: 3.0, 6: 2.5, 9: 4.125})));
    expect(cnt.value, equals(-0.375));
  });

  test('PosNegCounterValue applyChanges', () {
    DataConverter conv = new DataConverter<int, int>();
    var cnt = new TestPosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.applyChanges(conv.serialize(new ConvertedChange<int, int>({2: 4})));
    expect(cnt.value, equals(4));
    cnt.applyChanges(conv.serialize(new ConvertedChange<int, int>({2: 1})));
    expect(cnt.value, equals(1));
    cnt.applyChanges(conv.serialize(new ConvertedChange<int, int>({5: 5})));
    expect(cnt.value, equals(-4));
  });

  test('PosNegCounterValue onChange stream', () {
    DataConverter conv = new DataConverter<int, int>();
    var cnt = new TestPosNegCounterValue<int>(
        1, conv.serialize(new ConvertedChange({2: 1, 3: 2})));
    Stream<int> changeStream = cnt.onChange;
    expect(changeStream, emitsInOrder([2, 4, -3]));
    cnt
      ..applyChanges(conv.serialize(new ConvertedChange<int, int>({4: 3})))
      ..applyChanges(conv.serialize(new ConvertedChange<int, int>({2: 3})))
      ..applyChanges(conv.serialize(new ConvertedChange<int, int>({3: 9})));
  });
}

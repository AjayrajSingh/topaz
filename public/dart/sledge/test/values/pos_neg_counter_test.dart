// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:typed_data';

import 'package:sledge/src/document/uint8list_ops.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/pos_neg_counter_value.dart';
import 'package:test/test.dart';

void main() {
  final intMF = new Uint8ListMapFactory<int>();
  final doubleMF = new Uint8ListMapFactory<double>();

  test('PosNegCounterValue accumulate additions', () {
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]));
    expect(cnt.value, equals(0));
    cnt.add(1);
    expect(cnt.value, equals(1));
    cnt.add(5);
    expect(cnt.value, equals(6));
    cnt.add(3);
    expect(cnt.value, equals(9));
  });

  test('PosNegCounterValue accumulate subtractions', () {
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]));
    expect(cnt.value, equals(0));
    cnt.add(-1);
    expect(cnt.value, equals(-1));
    cnt.add(-2);
    expect(cnt.value, equals(-3));
    cnt.add(-3);
    expect(cnt.value, equals(-6));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]));
    expect(cnt.value, equals(0));
    cnt.add(-3);
    expect(cnt.value, equals(-3));
    cnt.add(2);
    expect(cnt.value, equals(-1));
    cnt.add(5);
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new PosNegCounterValue<double>(new Uint8List.fromList([1]));
    expect(cnt.value, equals(0.0));
    cnt.add(-3.2);
    expect(cnt.value, equals(-3.2));
    cnt.add(2.12);
    expect(cnt.value, equals(-1.08));
    cnt.add(5.0);
    expect(cnt.value, equals(3.92));
  });

  test('PosNegCounterValue construction', () {
    DataConverter conv = new DataConverter<Uint8List, int>();
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 1]), () => 4)
            ..putIfAbsent(new Uint8List.fromList([1, 1]), () => 3))));
    expect(cnt.value, equals(1));
  });

  test('PosNegCounterValue construction 2', () {
    DataConverter conv = new DataConverter<Uint8List, int>();
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 1]), () => 4)
            ..putIfAbsent(new Uint8List.fromList([1, 1]), () => 3)
            ..putIfAbsent(new Uint8List.fromList([0, 3]), () => 5)
            ..putIfAbsent(new Uint8List.fromList([1, 3]), () => 2))));
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue construction double', () {
    DataConverter conv = new DataConverter<Uint8List, double>();
    var cnt = new PosNegCounterValue<double>(new Uint8List.fromList([1]))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, double>(
          doubleMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 1]), () => 4.25)
            ..putIfAbsent(new Uint8List.fromList([1, 1]), () => 3.0)
            ..putIfAbsent(new Uint8List.fromList([0, 3]), () => 2.5)
            ..putIfAbsent(new Uint8List.fromList([1, 4]), () => 4.125))));
    expect(cnt.value, equals(-0.375));
  });

  test('PosNegCounterValue applyChange', () {
    DataConverter conv = new DataConverter<Uint8List, int>();
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]));
    expect(cnt.value, equals(0));
    cnt.applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
        intMF.newMap()..putIfAbsent(new Uint8List.fromList([0, 1]), () => 4))));
    expect(cnt.value, equals(4));
    cnt.applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
        intMF.newMap()..putIfAbsent(new Uint8List.fromList([0, 1]), () => 1))));
    expect(cnt.value, equals(1));
    cnt.applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
        intMF.newMap()..putIfAbsent(new Uint8List.fromList([1, 2]), () => 5))));
    expect(cnt.value, equals(-4));
  });

  test('PosNegCounterValue onChange stream', () {
    DataConverter conv = new DataConverter<Uint8List, int>();
    var cnt = new PosNegCounterValue<int>(new Uint8List.fromList([1]))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 1]), () => 1)
            ..putIfAbsent(new Uint8List.fromList([1, 1]), () => 2))));
    Stream<int> changeStream = cnt.onChange;
    expect(changeStream, emitsInOrder([2, 4, -3]));
    cnt
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 2]), () => 3))))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([0, 1]), () => 3))))
      ..applyChange(conv.serialize(new ConvertedChange<Uint8List, int>(
          intMF.newMap()
            ..putIfAbsent(new Uint8List.fromList([1, 1]), () => 9))));
  });
}

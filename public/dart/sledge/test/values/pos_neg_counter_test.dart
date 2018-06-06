// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:sledge/src/document/values/pos_neg_counter_value.dart';
import 'package:test/test.dart';

void main() {
  test('PosNegCounterValue accumulate additions', () {
    var cnt = new PosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(1);
    expect(cnt.value, equals(1));
    cnt.add(5);
    expect(cnt.value, equals(6));
    cnt.add(3);
    expect(cnt.value, equals(9));
  });

  test('PosNegCounterValue accumulate subtractions', () {
    var cnt = new PosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(-1);
    expect(cnt.value, equals(-1));
    cnt.add(-2);
    expect(cnt.value, equals(-3));
    cnt.add(-3);
    expect(cnt.value, equals(-6));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new PosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.add(-3);
    expect(cnt.value, equals(-3));
    cnt.add(2);
    expect(cnt.value, equals(-1));
    cnt.add(5);
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue accumulate', () {
    var cnt = new PosNegCounterValue<double>(1);
    expect(cnt.value, equals(0.0));
    cnt.add(-3.2);
    expect(cnt.value, equals(-3.2));
    cnt.add(2.12);
    expect(cnt.value, equals(-1.08));
    cnt.add(5.0);
    expect(cnt.value, equals(3.92));
  });

  Converter<int> intConverter = new Converter<int>();
  Converter<double> doubleConverter = new Converter<double>();

  test('PosNegCounterValue construction', () {
    var cnt = new PosNegCounterValue<int>(
        1,
        new Change([
          new KeyValue(intConverter.serialize(2), intConverter.serialize(4)),
          new KeyValue(intConverter.serialize(3), intConverter.serialize(3))
        ]));
    expect(cnt.value, equals(1));
  });

  test('PosNegCounterValue construction 2', () {
    var cnt = new PosNegCounterValue<int>(
        1,
        new Change([
          new KeyValue(intConverter.serialize(2), intConverter.serialize(4)),
          new KeyValue(intConverter.serialize(3), intConverter.serialize(3)),
          new KeyValue(intConverter.serialize(6), intConverter.serialize(5)),
          new KeyValue(intConverter.serialize(7), intConverter.serialize(2))
        ]));
    expect(cnt.value, equals(4));
  });

  test('PosNegCounterValue construction double', () {
    var cnt = new PosNegCounterValue<double>(
        1,
        new Change([
          new KeyValue(
              intConverter.serialize(2), doubleConverter.serialize(4.25)),
          new KeyValue(
              intConverter.serialize(3), doubleConverter.serialize(3.0)),
          new KeyValue(
              intConverter.serialize(6), doubleConverter.serialize(2.5)),
          new KeyValue(
              intConverter.serialize(9), doubleConverter.serialize(4.125))
        ]));
    expect(cnt.value, equals(-0.375));
  });

  test('PosNegCounterValue applyChanges', () {
    var cnt = new PosNegCounterValue<int>(1);
    expect(cnt.value, equals(0));
    cnt.applyChanges(new Change(
        [new KeyValue(intConverter.serialize(2), intConverter.serialize(4))]));
    expect(cnt.value, equals(4));
    cnt.applyChanges(new Change(
        [new KeyValue(intConverter.serialize(2), intConverter.serialize(1))]));
    expect(cnt.value, equals(1));
    cnt.applyChanges(new Change(
        [new KeyValue(intConverter.serialize(5), intConverter.serialize(5))]));
    expect(cnt.value, equals(-4));
  });

  test('PosNegCounterValue onChange stream', () {
    var cnt = new PosNegCounterValue<int>(
        1,
        new Change([
          new KeyValue(intConverter.serialize(2), intConverter.serialize(1)),
          new KeyValue(intConverter.serialize(3), intConverter.serialize(2))
        ]));
    Stream<int> changeStream = cnt.onChange;
    expect(changeStream, emitsInOrder([2, 4, -3]));
    cnt
      ..applyChanges(new Change(
          [new KeyValue(intConverter.serialize(4), intConverter.serialize(3))]))
      ..applyChanges(new Change(
          [new KeyValue(intConverter.serialize(2), intConverter.serialize(3))]))
      ..applyChanges(new Change([
        new KeyValue(intConverter.serialize(3), intConverter.serialize(9))
      ]));
  });
}

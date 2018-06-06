// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:sledge/src/document/values/lww_value.dart';
import 'package:test/test.dart';

void main() {
  test('Integer', () {
    var cnt = new LastOneWinValue<int>();
    expect(cnt.value, equals(0));
    cnt.value = 3;
    expect(cnt.value, equals(3));
    cnt.value = -5;
    expect(cnt.value, equals(-5));
  });

  test('Double', () {
    var cnt = new LastOneWinValue<double>();
    expect(cnt.value, equals(0.0));
    cnt.value = 3.5;
    expect(cnt.value, equals(3.5));
    cnt.value = -5.25;
    expect(cnt.value, equals(-5.25));
  });

  test('Boolean', () {
    var cnt = new LastOneWinValue<bool>();
    expect(cnt.value, equals(false));
    cnt.value = true;
    expect(cnt.value, equals(true));
    cnt.value = false;
    expect(cnt.value, equals(false));
  });

  test('String', () {
    var cnt = new LastOneWinValue<String>();
    expect(cnt.value, equals(''));
    cnt.value = 'aba';
    expect(cnt.value, equals('aba'));
    cnt.value = 'foo';
    expect(cnt.value, equals('foo'));
  });

  Converter<int> intConverter = new Converter<int>();
  Converter<double> doubleConverter = new Converter<double>();
  Converter<bool> boolConverter = new Converter<bool>();
  Converter<String> stringConverter = new Converter<String>();

  test('Integer oprations', () {
    var x = new LastOneWinValue<int>(new Change(
        [new KeyValue(intConverter.serialize(0), intConverter.serialize(-3))]));
    expect(x.value, equals(-3));
    x.applyChanges(new Change(
        [new KeyValue(intConverter.serialize(0), intConverter.serialize(5))]));
    expect(x.value, equals(5));
    x.value = 2;
    expect(x.value, equals(2));
    x.value = -1;
    expect(x.value, equals(-1));
    x.put();
    expect(x.value, equals(-1));
    x.applyChanges(new Change(
        [new KeyValue(intConverter.serialize(0), intConverter.serialize(4))]));
    expect(x.value, equals(4));
  });

  test('Double operations', () {
    var x = new LastOneWinValue<double>(new Change([
      new KeyValue(intConverter.serialize(0), doubleConverter.serialize(-3.5))
    ]));
    expect(x.value, equals(-3.5));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), doubleConverter.serialize(4.2))
    ]));
    expect(x.value, equals(4.2));
    x.value = 0.5;
    expect(x.value, equals(0.5));
    x.value = -1.0;
    expect(x.value, equals(-1.0));
    x.put();
    expect(x.value, equals(-1.0));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), doubleConverter.serialize(4.25))
    ]));
    expect(x.value, equals(4.25));
  });

  test('String operations', () {
    var x = new LastOneWinValue<String>(new Change([
      new KeyValue(intConverter.serialize(0), stringConverter.serialize('bar'))
    ]));
    expect(x.value, equals('bar'));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), stringConverter.serialize('foo'))
    ]));
    expect(x.value, equals('foo'));
    x.value = 'bar';
    expect(x.value, equals('bar'));
    x.value = 'tor';
    expect(x.value, equals('tor'));
    x.put();
    expect(x.value, equals('tor'));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), stringConverter.serialize('cir'))
    ]));
    expect(x.value, equals('cir'));
  });

  test('Boolean operations', () {
    var x = new LastOneWinValue<bool>(new Change([
      new KeyValue(intConverter.serialize(0), boolConverter.serialize(true))
    ]));
    expect(x.value, equals(true));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), boolConverter.serialize(false))
    ]));
    expect(x.value, equals(false));
    x.value = true;
    expect(x.value, equals(true));
    x.put();
    expect(x.value, equals(true));
    x.applyChanges(new Change([
      new KeyValue(intConverter.serialize(0), boolConverter.serialize(false))
    ]));
    expect(x.value, equals(false));
  });

  test('onChange stream', () {
    var cnt = new LastOneWinValue<String>(new Change([
      new KeyValue(intConverter.serialize(0), stringConverter.serialize('aba'))
    ]));
    Stream<String> changeStream = cnt.onChange;
    expect(changeStream, emitsInOrder(['bar', 'foo', 'a']));
    cnt
      ..applyChanges(new Change([
        new KeyValue(
            intConverter.serialize(0), stringConverter.serialize('bar'))
      ]))
      ..applyChanges(new Change([
        new KeyValue(
            intConverter.serialize(0), stringConverter.serialize('foo'))
      ]))
      ..applyChanges(new Change([
        new KeyValue(intConverter.serialize(0), stringConverter.serialize('a'))
      ]));
  });
}

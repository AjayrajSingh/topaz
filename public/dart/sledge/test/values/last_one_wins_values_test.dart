// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:typed_data';

import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/converter.dart';
import 'package:sledge/src/document/values/last_one_wins_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

class TestLastOneWinsValue<T> extends LastOneWinsValue<T> {
  TestLastOneWinsValue([Change init]) : super(init) {
    observer = new DummyValueObserver();
  }
}

void main() {
  test('Integer', () {
    var cnt = new TestLastOneWinsValue<int>();
    expect(cnt.value, equals(0));
    cnt.value = 3;
    expect(cnt.value, equals(3));
    cnt.value = -5;
    expect(cnt.value, equals(-5));
  });

  test('Double', () {
    var cnt = new TestLastOneWinsValue<double>();
    expect(cnt.value, equals(0.0));
    cnt.value = 3.5;
    expect(cnt.value, equals(3.5));
    cnt.value = -5.25;
    expect(cnt.value, equals(-5.25));
  });

  test('Boolean', () {
    var cnt = new TestLastOneWinsValue<bool>();
    expect(cnt.value, equals(false));
    cnt.value = true;
    expect(cnt.value, equals(true));
    cnt.value = false;
    expect(cnt.value, equals(false));
  });

  test('String', () {
    var cnt = new TestLastOneWinsValue<String>();
    expect(cnt.value, equals(''));
    cnt.value = 'aba';
    expect(cnt.value, equals('aba'));
    cnt.value = 'foo';
    expect(cnt.value, equals('foo'));
  });

  test('Uint8List', () {
    var cnt = new TestLastOneWinsValue<Uint8List>();
    expect(cnt.value, equals(new Uint8List(0)));
    cnt.value = new Uint8List.fromList([1, 2, 3]);
    expect(cnt.value, equals(new Uint8List.fromList([1, 2, 3])));
    cnt.value = new Uint8List.fromList([2, 5, 3]);
    expect(cnt.value, equals(new Uint8List.fromList([2, 5, 3])));
  });

  test('Integer oprations', () {
    final conv = new DataConverter<int, int>();
    var x = new TestLastOneWinsValue<int>(
        conv.serialize(new ConvertedChange<int, int>({0: -3})));
    expect(x.value, equals(-3));
    x.applyChange(conv.serialize(new ConvertedChange<int, int>({0: 5})));
    expect(x.value, equals(5));
    x.value = 2;
    expect(x.value, equals(2));
    x.value = -1;
    expect(x.value, equals(-1));
    x.getChange();
    expect(x.value, equals(-1));
    x.applyChange(conv.serialize(new ConvertedChange<int, int>({0: 4})));
    expect(x.value, equals(4));
  });

  test('Double operations', () {
    final conv = new DataConverter<int, double>();
    var x = new TestLastOneWinsValue<double>(
        conv.serialize(new ConvertedChange<int, double>({0: -3.5})));
    expect(x.value, equals(-3.5));
    x.applyChange(conv.serialize(new ConvertedChange<int, double>({0: 4.2})));
    expect(x.value, equals(4.2));
    x.value = 0.5;
    expect(x.value, equals(0.5));
    x.value = -1.0;
    expect(x.value, equals(-1.0));
    x.getChange();
    expect(x.value, equals(-1.0));
    x.applyChange(conv.serialize(new ConvertedChange<int, double>({0: 4.25})));
    expect(x.value, equals(4.25));
  });

  test('String operations', () {
    final conv = new DataConverter<int, String>();
    var x = new TestLastOneWinsValue<String>(
        conv.serialize(new ConvertedChange<int, String>({0: 'bar'})));
    expect(x.value, equals('bar'));
    x.applyChange(conv.serialize(new ConvertedChange<int, String>({0: 'foo'})));
    expect(x.value, equals('foo'));
    x.value = 'bar';
    expect(x.value, equals('bar'));
    x.value = 'tor';
    expect(x.value, equals('tor'));
    x.getChange();
    expect(x.value, equals('tor'));
    x.applyChange(conv.serialize(new ConvertedChange<int, String>({0: 'cir'})));
    expect(x.value, equals('cir'));
  });

  test('Boolean operations', () {
    final conv = new DataConverter<int, bool>();
    var x = new TestLastOneWinsValue<bool>(
        conv.serialize(new ConvertedChange<int, bool>({0: true})));
    expect(x.value, equals(true));
    x.applyChange(conv.serialize(new ConvertedChange<int, bool>({0: false})));
    expect(x.value, equals(false));
    x.value = true;
    expect(x.value, equals(true));
    x.getChange();
    expect(x.value, equals(true));
    x.applyChange(conv.serialize(new ConvertedChange<int, bool>({0: false})));
    expect(x.value, equals(false));
  });

  test('onChange stream', () {
    final conv = new DataConverter<int, String>();
    var x = new TestLastOneWinsValue<String>(
        conv.serialize(new ConvertedChange<int, String>({0: 'aba'})));
    Stream<String> changeStream = x.onChange;
    expect(changeStream, emitsInOrder(['bar', 'foo', 'a']));
    x
      ..applyChange(
          conv.serialize(new ConvertedChange<int, String>({0: 'bar'})))
      ..applyChange(
          conv.serialize(new ConvertedChange<int, String>({0: 'foo'})))
      ..applyChange(conv.serialize(new ConvertedChange<int, String>({0: 'a'})));
  });
}

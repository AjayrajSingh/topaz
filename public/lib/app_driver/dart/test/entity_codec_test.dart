// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
// import 'dart:convert';

import 'package:test/test.dart';
import 'package:lib.app_driver.dart/entity_codec.dart';

void main() {
  group('EntityCodec<T> streaming transform', () {
    final EntityCodec<BasicExample> codec = new EntityCodec<BasicExample>(
      type: 'com.example.basic',
      encode: (BasicExample value) => value.name,
      decode: (String data) => new BasicExample(data),
    );

    test('stream.transform(codec)', () async {
      List<String> list = <String>['foo', 'bar', 'baz'];

      Stream<String> stream = new Stream<String>.fromIterable(list);
      List<String> results = await stream
          .transform(codec.decoder)
          .map((BasicExample e) => e.name)
          .toList();

      expect(results.length, equals(list.length));
    });

    // test('codec.decoder.startChunkedConversion(sink)', () {

    // }, skip: true);
  });

  // test('wut', () {
  //   expect(true, equals(false));
  // });
}

class BasicExample {
  final String name;

  BasicExample(this.name);
}

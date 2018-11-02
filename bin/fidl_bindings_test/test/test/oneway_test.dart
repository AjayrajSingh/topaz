// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:fidl_fidl_examples_bindingstest/fidl_async.dart';

import './server.dart';

void main() async {
  TestServerInstance server;

  group('one way', () {
    setUpAll(() async {
      server = new TestServerInstance();
      await server.start();
    });

    tearDownAll(() async {
      await server.stop();
      server = null;
    });

    test('no args', () async {
      await server.proxy.oneWayNoArgs();
      final bool received = await server.proxy.receivedOneWayNoArgs();
      expect(received, isTrue);
    });

    test('string arg', () async {
      await server.proxy.oneWayStringArg('Hello, world');
      final String stringReply = await server.proxy.receivedOneWayString();
      expect(stringReply, equals('Hello, world'));
    });

    test('three args', () async {
      final primes =
          new Uint8List.fromList([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]);
      await server.proxy.oneWayThreeArgs(
          23, 42, new NoHandleStruct(foo: 'hello', bar: 1729, baz: primes));
      final threeReply = await server.proxy.receivedOneWayThreeArgs();
      expect(threeReply.x, equals(23));
      expect(threeReply.y, equals(42));
      expect(threeReply.z.foo, equals('hello'));
      expect(threeReply.z.bar, equals(1729));
      expect(threeReply.z.baz, unorderedEquals(primes));
    });

    test('table', () async {
      final primes =
          new Uint8List.fromList([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]);
      await server.proxy.oneWayExampleTable(
          new ExampleTable(foo: 'hello', bar: 1729, baz: primes));
      final received = await server.proxy.receivedOneWayExampleTable();
      expect(received.foo, equals('hello'));
      expect(received.bar, equals(1729));
      expect(received.baz, unorderedEquals(primes));
    });

    test('partial table', () async {
      await server.proxy.oneWayExampleTable(
          new ExampleTable(bar: 1729)); // not seting foo, nor baz
      final received = await server.proxy.receivedOneWayExampleTable();
      expect(received.foo, equals(null));
      expect(received.bar, equals(1729));
      expect(received.baz, equals(null));
    });

    test('empty table', () async {
      await server.proxy.oneWayExampleTable(
          new ExampleTable());
      final received = await server.proxy.receivedOneWayExampleTable();
      expect(received.foo, equals(null));
      expect(received.bar, equals(null));
      expect(received.baz, equals(null));
    });
  });
}

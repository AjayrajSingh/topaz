// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:async/async.dart';
import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:lib.testing.app_driver.dart/fake_module_driver.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:test/test.dart';

const _action = 'action';

const _key1 = 'key1';
const _value1 = 'value1';
const _value2 = 'value2';

class _StringCodec extends EntityCodec<String> {
  _StringCodec()
      : super(
          type: 'com.fuchsia.string',
          encode: (String s) => s,
          decode: (String s) => s,
        );
}

void main() async {
  FakeModuleDriver moduleDriver;

  setUp(() {
    moduleDriver = FakeModuleDriver();
  });

  test('test start', () {
    expect(moduleDriver.start(), completion(moduleDriver));
  });

  test('test put and getTestLinkValue', () {
    moduleDriver.put(_key1, _value1, _StringCodec());
    expect(
        moduleDriver.getTestLinkCurrentValue(_key1, _StringCodec()), _value1);
  });

  test('test putTestValue and getTestLinkValue', () {
    moduleDriver.putTestValue(_key1, _value1, _StringCodec());

    expect(
        moduleDriver.getTestLinkCurrentValue(_key1, _StringCodec()), _value1);
  });

  test('test startModule and intent history', () {
    Intent intent = Intent(action: _action);

    moduleDriver.startModule(intent: intent);

    expect(moduleDriver.getTestStartModuleIntents(), containsAll([intent]));
  });

  test('test putTestValue and watch', () {
    StreamQueue<String> watchQueue =
        StreamQueue<String>(moduleDriver.watch(_key1, _StringCodec()));
    StreamQueue<String> watchQueue2 =
        StreamQueue<String>(moduleDriver.watch(_key1, _StringCodec()));

    moduleDriver
      ..putTestValue(_key1, _value1, _StringCodec())
      ..putTestValue(_key1, _value2, _StringCodec());

    expect(watchQueue, emitsInOrder([_value1, _value2]));
    expect(watchQueue2, emitsInOrder([_value1, _value2]));
  });

  test('test put and watch', () {
    StreamQueue<String> watchQueue = StreamQueue<String>(
        moduleDriver.watch(_key1, _StringCodec(), all: false));
    StreamQueue<String> watchAllQueue = StreamQueue<String>(
        moduleDriver.watch(_key1, _StringCodec(), all: true));

    moduleDriver
      ..put(_key1, _value1, _StringCodec())
      ..put(_key1, _value2, _StringCodec())
      ..cleanUp();

    expect(watchQueue, emitsDone);
    expect(watchQueue.eventsDispatched, 0);
    expect(watchAllQueue, emitsInOrder([_value1, _value2]));
  });

  tearDown(() {
    moduleDriver.cleanUp();
  });
}

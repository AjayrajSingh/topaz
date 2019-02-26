// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_modular/src/module/internal/_streaming_intent_handler_impl.dart';
import 'package:fuchsia_modular/src/module/intent.dart';

import 'package:test/test.dart';

void main() {
  group('streaming intent handler', () {
    StreamingIntentHandlerImpl handler;
    _StubLifecycle lifecycle;

    setUp(() {
      lifecycle = _StubLifecycle();
      handler = StreamingIntentHandlerImpl(lifecycle: lifecycle);
    });

    test('stream receives intent', () {
      final intent = Intent(action: 'foo');
      expect(handler.stream, emits(intent));
      handler.handleIntent(intent);
    });

    test('stream emits many', () {
      final intent1 = Intent(action: 'foo');
      final intent2 = Intent(action: 'bar');

      expect(
          handler.stream,
          emitsInOrder([
            intent1,
            intent2,
          ]));

      handler..handleIntent(intent1)..handleIntent(intent2);
    });

    test('stream closes when lifecycle terminates', () {
      expect(handler.stream, emitsDone);
      lifecycle.terminate();
    });

    test('stream is not a broadcast stream', () {
      expect(handler.stream.isBroadcast, isFalse);
    });
  });
}

class _StubLifecycle implements Lifecycle {
  final _listeners = <Future<void> Function()>[];

  @override
  bool addTerminateListener(Future<void> Function() listener) {
    _listeners.add(listener);
    return true;
  }

  void terminate() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

void main() {
  test('create eventpair', () {
    final HandlePairResult pair = System.eventpairCreate();
    expect(pair.status, equals(ZX.OK));
    expect(pair.first.isValid, isTrue);
    expect(pair.second.isValid, isTrue);
  });

  test('close eventpair', () {
    final HandlePairResult pair = System.eventpairCreate();
    expect(pair.first.close(), equals(0));
    expect(pair.first.isValid, isFalse);
    expect(pair.second.isValid, isTrue);

    expect(pair.second.close(), equals(0));
    expect(pair.second.isValid, isFalse);
  });

  test('async wait peer closed', () async {
    final HandlePairResult pair = System.eventpairCreate();
    final Completer<int> completer = new Completer<int>();
    pair.first.asyncWait(EventPair.PEER_CLOSED, (int status, int pending) {
      completer.complete(status);
    });

    expect(completer.isCompleted, isFalse);
    pair.second.close();

    final int status = await completer.future;
    expect(status, equals(ZX.OK));
  });
}
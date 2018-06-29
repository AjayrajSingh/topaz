// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/pos_neg_counter_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/storage_state.dart';
import '../dummies/dummy_value_observer.dart';

class TestPosNegCounterValue<T extends num> extends PosNegCounterValue<T> {
  TestPosNegCounterValue(Uint8List id, [Change init]) : super(id, init) {
    observer = new DummyValueObserver();
  }
}

void main() {
  test('PosNegCounterValue with StorageState', () {
    var cnt1 = new TestPosNegCounterValue<int>(new Uint8List.fromList([1])),
        cnt2 = new TestPosNegCounterValue<int>(new Uint8List.fromList([2])),
        cnt3 = new TestPosNegCounterValue<int>(new Uint8List.fromList([3]));
    var ss1 = new StorageState(),
        ss2 = new StorageState(),
        ss3 = new StorageState();
    cnt1.add(4);
    cnt2.add(2);
    ss1.applyChange(cnt1.getChange(), 1);
    ss2.applyChange(cnt2.getChange(), 2);
    cnt2.applyChange(ss2.updateWith(ss1));
    expect(cnt1.value, equals(4));
    expect(cnt2.value, equals(6));
    cnt1.applyChange(ss1.updateWith(ss2));
    expect(cnt2.value, equals(6));
    cnt3.applyChange(ss3.updateWith(ss2));
    expect(cnt3.value, equals(6));
  });
}

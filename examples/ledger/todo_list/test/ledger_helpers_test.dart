// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

// ignore: implementation_imports
import 'package:todo_list/src/ledger_helpers.dart' as ledger_helpers;

class MockPageSnapshotProxy extends Mock implements ledger.PageSnapshotProxy {}

void main() {
  group('ledger helpers', () {
    // Regression test for LE-819. This ensures that the get entries helper
    // calls its callback in the simplest case: where there is no entries and no
    // continuation token.
    test('getEntriesFromSnapshot_completes', () async {
      // Response: no entries, no continuation token.
      final response = ledger.PageSnapshot$GetEntriesInline$Response([], null);
      final MockPageSnapshotProxy pageSnapshot = MockPageSnapshotProxy();
      when(pageSnapshot.getEntriesInline(any, any))
          .thenAnswer((_) => Future.value(response));

      Completer completer = Completer();
      ledger_helpers.getEntriesFromSnapshot(pageSnapshot, (var items) {
        completer.complete(items);
      });
      final result = await completer.future;
      expect(result, equals({}));
    });
  });
}

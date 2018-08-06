// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

// ignore_for_file: library_prefixes
import 'package:lib.app.dart/logging.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:sledge/src/ledger_helpers.dart';
import 'package:sledge/src/document/change.dart';
import 'package:test/test.dart';

import 'values/matchers.dart';

void main() {
  setupLogger();

  group('Transform ledger types.', () {
    test('Convert empty change', () {
      const emptyPageChange = const ledger.PageChange(
          timestamp: 0,
          changedEntries: const <ledger.Entry>[],
          deletedKeys: const <Uint8List>[]);
      final change = getChangeFromPageChange(emptyPageChange);
      expect(change, new ChangeMatcher(new Change()));
    });

    test('Convert non empty change', () {
      final pageChange = new ledger.PageChange(
          timestamp: 0,
          changedEntries: <ledger.Entry>[],
          deletedKeys: <Uint8List>[
            new Uint8List.fromList([0]),
            new Uint8List.fromList([1, 2])
          ]);
      final ourChange = new Change([], [
        new Uint8List.fromList([0]),
        new Uint8List.fromList([1, 2])
      ]);

      final change = getChangeFromPageChange(pageChange);
      expect(change, new ChangeMatcher(ourChange));
    });
  });
}

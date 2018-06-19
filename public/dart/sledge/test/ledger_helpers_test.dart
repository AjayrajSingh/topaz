import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl.dart' as lib$fuchsia_mem;
import 'package:sledge/src/ledger_helpers.dart';
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

import 'values/matchers.dart';

void main() {
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

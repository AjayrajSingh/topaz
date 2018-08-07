// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import '../document/document_id.dart';
import '../schema/schema.dart';

/// Returns the list of Documents changes.
Map<DocumentId, List<ledger.DiffEntry>> documentChangeMap(
    List<ledger.DiffEntry> diffs, Map<Uint8List, Schema> map) {
  // TODO: implement.
  throw new UnimplementedError(
      'the method [documentChangeMap] is not yet implemented');
  return <DocumentId, List<ledger.DiffEntry>>{};
}

/// Resolve the conflicts [diffs] that concern the document identified with
/// [id].
List<ledger.MergedValue> resolveConflict(
    DocumentId id, List<ledger.DiffEntry> diffs) {
  // TODO: implement.
  return <ledger.MergedValue>[];
}

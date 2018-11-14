// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import '../document/document_id.dart' show DocumentId;
import '../ledger_helpers.dart';
import '../schema/schema.dart';
import 'document_conflict_resolver.dart';
import 'schemas_obtainer.dart';

/// The conflict resolver (CR) called for every page.
///
/// The CR essentially gets a list of Key Values (KVs) that changed.
/// In order to know how to resolve the conflicts, the CR needs to know for
/// each KV what is the schema of the document it belongs to.
/// For example, a conflict on a KV that encodes the "LastOneWins" field of
/// a schema will be resolved differently from a KV that encodes an
/// hypothetical "MaxOneWins" field.
///
/// Sledge (and therefore the CR) does not know all the Schemas that are in
/// use: a new Schema may have been started to be used on other devices.
/// The local Sledge instance still has to be able to know about it to
/// resolve the conflict, so the Schemas are read from the left and right
/// snapshots.
class ConflictResolver extends ledger.ConflictResolver {
  @override
  void resolve(
      InterfaceHandle<ledger.PageSnapshot> left,
      InterfaceHandle<ledger.PageSnapshot> right,
      InterfaceHandle<ledger.PageSnapshot> commonVersion,
      InterfaceHandle<ledger.MergeResultProvider> newResultProvider) async {
    // Obtain the left and right snapshots.
    ledger.PageSnapshotProxy leftPageSnapshot = new ledger.PageSnapshotProxy();
    ledger.PageSnapshotProxy rightPageSnapshot = new ledger.PageSnapshotProxy();
    leftPageSnapshot.ctrl.bind(left);
    rightPageSnapshot.ctrl.bind(right);

    // Obtain all the schemas stored in the snapshots.
    Map<Uint8List, Schema> schemaMap =
        await getMapOfAllSchemas(leftPageSnapshot, rightPageSnapshot);

    // Find all the KVs that changed.
    final resultProviderProxy = new ledger.MergeResultProviderProxy();
    resultProviderProxy.ctrl.bind(newResultProvider);
    List<ledger.DiffEntry> diffs =
        await getConflictingDiff(resultProviderProxy);

    // Find all the ids of the documents that changed.
    Map<DocumentId, List<ledger.DiffEntry>> map =
        documentChangeMap(diffs, schemaMap);

    // ignore: cascade_invocations
    map.forEach((DocumentId id, List<ledger.DiffEntry> diffs) {
      List<ledger.MergedValue> mergedValues = resolveConflict(id, diffs);
      resultProviderProxy.merge(mergedValues, (ledger.Status status) {
        checkStatus(status, 'merge of values failed');
      });
      // TODO: coalesce the mergedValues to reduce the number of calls to
      // resultProviderProxy.Merge.
    });

    resultProviderProxy.done((ledger.Status status) {
      checkStatus(status, 'completion of merge failed');
    });
  }
}

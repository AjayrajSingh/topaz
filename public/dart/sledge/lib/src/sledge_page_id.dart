// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

import 'uint8list_ops.dart';
import 'version.dart';

/// Convenience wrapper of Ledger's page id.
/// For a given `pageName`, SledgePageId will generate a ledger.PageId with the
/// following format: sledge${sledgeVersion}_${hash(pageName)}.
class SledgePageId {
  ledger.PageId _id;

  /// The prefix of the Ledger page managed by Sledge.
  static final Uint8List prefix = utf8.encode(_sledgePageIdPrefix());

  /// Convenience constructor that takes an optional string.
  SledgePageId([String pageName = '']) {
    pageName ??= '';

    final Uint8List hashedPageName = hash(Utf8Encoder().convert(pageName));

    final encodedPageName = concatUint8Lists(prefix, hashedPageName);

    final trimmedEncodedPageName = encodedPageName.sublist(0, 16);
    assert(trimmedEncodedPageName.length == 16);

    _id = ledger.PageId(id: trimmedEncodedPageName);
  }

  /// The Ledger's PageId.
  // TODO: rename into ledgePageId.
  ledger.PageId get id => _id;

  /// Returns the prefix of a ledger PageId managed by the current version of
  /// Sledge.
  static String _sledgePageIdPrefix() {
    return 'sledge${sledgeVersion}_';
  }

  /// Returns true if the page identified with [pageId] is managed by this
  /// version of Sledge.
  static bool pageIsManagedBySledge(ledger.PageId pageId) {
    final pageIdPrefix = getSublistView(pageId.id, end: prefix.length);
    return ListEquality<int>().equals(pageIdPrefix, prefix);
  }
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

/// Convenience wrapper of Ledger's page id.
class SledgePageId {
  /// The Ledger's PageId.
  ledger.PageId id;

  /// Convenience constructor that takes an optional string.
  SledgePageId([String pageName = '']) {
    pageName ??= '';

    // TODO: use the hash of [pageName] and then add unittests.
    List<int> encodedPageName =
        new List<int>.from(utf8.encode('sledge_$pageName'));
    if (encodedPageName.length > 16) {
      throw new FormatException('page name too long');
    }
    while (encodedPageName.length < 16) {
      encodedPageName.add(0);
    }

    id = new ledger.PageId(id: new Uint8List.fromList(encodedPageName));
  }
}

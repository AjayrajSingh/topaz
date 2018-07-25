// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

void main() {
  test('Create SledgePageId objects', () {
    final a = new SledgePageId();
    final b = new SledgePageId('');
    final c = new SledgePageId('foo');
    final d = new SledgePageId(
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
    expect(a.id.id, equals(b.id.id));
    expect(SledgePageId.pageIsManagedBySledge(a.id), equals(true));
    expect(SledgePageId.pageIsManagedBySledge(b.id), equals(true));
    expect(SledgePageId.pageIsManagedBySledge(c.id), equals(true));
    expect(SledgePageId.pageIsManagedBySledge(d.id), equals(true));
  });

  test('pageIsManagedBySledge detects PageIds not managed by Sledge', () {
    final bytes = new Uint8List(16);
    final pageId = new ledger.PageId(id: bytes);
    expect(SledgePageId.pageIsManagedBySledge(pageId), equals(false));
  });

  test('make sure PageIds are not accidentely updated', () {
    final sledgePageId = new SledgePageId('foo');
    expect(
        sledgePageId.id.id,
        equals([
          115,
          108,
          101,
          100,
          103,
          101,
          48,
          95,
          44,
          38,
          180,
          107,
          104,
          255,
          198,
          143
        ]));
  });
}

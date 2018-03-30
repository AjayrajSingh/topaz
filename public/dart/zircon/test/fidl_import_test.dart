// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart' as link;
import 'package:test/test.dart';

void main(List<String> args) {
  test('Constructor test', () {
    link.LinkGetResponseParams r = const link.LinkGetResponseParams(json: 'test');
    expect(r.json, equals('test'));
  });
}

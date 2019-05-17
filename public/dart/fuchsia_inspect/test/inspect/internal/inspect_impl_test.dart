// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fuchsia_inspect/src/inspect/internal/_inspect_impl.dart';
import 'package:fuchsia_inspect/src/vmo/vmo_writer.dart';
import 'package:fuchsia_services/services.dart';
import 'package:test/test.dart';

import '../../util.dart';

void main() {
  test('Inspect root node is non-null by default', () {
    var context = StartupContext.fromStartupInfo();
    var vmo = FakeVmo(512);
    var writer = VmoWriter(vmo);

    var inspect = InspectImpl(context, writer);
    expect(inspect.root, isNotNull);
  });
}

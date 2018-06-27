// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:sledge/src/document/values/key_value_storage.dart';
import 'package:test/test.dart';

import 'map_api_tester.dart';

void main() {
  group('Map API coverage', () {
    final tester = new MapApiTester<KeyValueStorage>(
        () => new KeyValueStorage<int, int>());
    // ignore: cascade_invocations
    tester.testApi();
  });

  // TODO: add tests to check that all operations continue work as expected with
  // put, applyChanges and rollback
}

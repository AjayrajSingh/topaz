// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/services/service_provider_impl.dart';

void main() {
  group('service provider impl', () {
    test('connect to service calls correct thunk', () async {
      final impl = ServiceProviderImpl();
      bool wasCalled = false;
      impl.addServiceForName((_) {
        wasCalled = true;
      }, 'foo');

      await impl.connectToService('foo', null);
      expect(wasCalled, isTrue);
    });
  });
}

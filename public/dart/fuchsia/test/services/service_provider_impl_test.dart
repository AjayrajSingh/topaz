// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'package:fuchsia/src/services/service_provider_impl.dart'; // ignore: implementation_imports

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

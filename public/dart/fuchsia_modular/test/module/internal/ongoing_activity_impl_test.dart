// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fuchsia_modular;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:fuchsia_modular/src/module/internal/_ongoing_activity_impl.dart'; // ignore: implementation_imports

class MockyProxyController extends Mock
    implements AsyncProxyController<fuchsia_modular.OngoingActivityProxy> {}

class MockProxy extends Mock implements fuchsia_modular.OngoingActivityProxy {
  final MockyProxyController _ctrl;

  MockProxy(this._ctrl) : super();

  @override
  AsyncProxyController<fuchsia_modular.OngoingActivityProxy> get ctrl => _ctrl;
}

void main() {
  group('ongoing activity impl', () {
    MockyProxyController mockControler;
    MockProxy mockProxy;

    setUp(() {
      mockControler = MockyProxyController();
      mockProxy = MockProxy(mockControler);
    });

    test('calls close on the proxy when done called', () {
      OngoingActivityImpl(mockProxy).done();
      verify(mockControler.close());
    });

    test('throws when done called twice', () {
      final activity = OngoingActivityImpl(mockProxy)..done();
      expect(activity.done, throwsException);
    });
  });
}

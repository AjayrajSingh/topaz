// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_io/fidl_async.dart';
import 'package:fuchsia_services/src/outgoing.dart';
import 'package:test/test.dart';

void main() {
  StreamController<bool> _streamController;
  Stream<bool> _stream;

  setUp(() {
    _streamController = StreamController<bool>.broadcast();
    _stream = _streamController.stream;
  });

  tearDown(() {
    _streamController.close();
  });

  group('outgoing', () {
    test('connect to service calls correct service', () async {
      final outgoingImpl = Outgoing();
      final dirProxy = DirectoryProxy();
      outgoingImpl
        ..addPublicService(
          (_) {
            _streamController.add(true);
          },
          'foo',
        )
        ..serve(InterfaceRequest(dirProxy.ctrl.request().passChannel()));
      {
        final nodeProxy = NodeProxy();
        await dirProxy.open(0, 0, 'public/foo', nodeProxy.ctrl.request());
      }
      {
        final nodeProxy = NodeProxy();
        await dirProxy.open(0, 0, 'svc/foo', nodeProxy.ctrl.request());
      }
      _stream.listen(expectAsync1((response) {
        expect(response, true);
      }, count: 2));
    });
  });
}

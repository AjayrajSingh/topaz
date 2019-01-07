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
  group('outgoing', () {
    test('connect to service calls correct service', () async {
      final impl = Outgoing();
      StreamController<bool> streamController =
          new StreamController.broadcast();
      Stream stream = streamController.stream;
      impl.addPublicService((_) {
        streamController
          ..add(true)
          ..close();
      }, 'foo');

      var proxy = DirectoryProxy();
      impl.serve(InterfaceRequest(proxy.ctrl.request().passChannel()));

      var nodeProxy = NodeProxy();
      await proxy.open(0, 0, 'public/foo', nodeProxy.ctrl.request());
      stream.listen(expectAsync1((response) {
        expect(response, true);
      }));
    });
  });
}

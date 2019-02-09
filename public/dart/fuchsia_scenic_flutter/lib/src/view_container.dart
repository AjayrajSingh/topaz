// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1/fidl_async.dart';
import 'package:zircon/zircon.dart';

import 'internal/_mozart.dart';
import 'view_container_listener_impl.dart';

int _nextViewKey = 1;

ViewContainerProxy _initViewContainer() {
  // Analyzer doesn't know Handle must be dart:zircon's Handle
  final Handle handle = ScenicStartupInfo.takeViewContainer();
  if (handle == null) {
    return null;
  }
  final ViewContainerProxy proxy = new ViewContainerProxy()
    ..ctrl.bind(new InterfaceHandle<ViewContainer>(new Channel(handle)))
    ..setListener(ViewContainerListenerImpl.instance.createInterfaceHandle());

  assert(() {
    proxy.ctrl.whenClosed.then((_) async {
      print('ViewContainerProxy: closed');
    });
    return true;
  }());

  return proxy;
}

/// The global |ViewContainer| for this flutter isolate.
final ViewContainerProxy globalViewContainer = _initViewContainer();

/// Obtain a new view key from the global counter for this flutter isolate.
int nextGlobalViewKey() {
  return _nextViewKey++;
}

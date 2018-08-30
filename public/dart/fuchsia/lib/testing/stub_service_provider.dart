// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:zircon/zircon.dart';

/// Provides a stubbed out subclass of [ServiceProvider] which
/// aids in testing.
class StubServiceProvider extends ServiceProvider {
  /// An optional function to run when connectToService is called.
  final Future<Null> Function(String, Channel) onConnectToService;

  /// The default constructor for this object.
  ///
  /// [onConnectToService] is an optional function which will
  /// run when connectToService is called providing a hook for
  /// extra code to run.
  StubServiceProvider({this.onConnectToService});

  @override
  Future<Null> connectToService(String serviceName, Channel channel) async {
    if (onConnectToService != null) {
      await onConnectToService(serviceName, channel);
    }
  }
}

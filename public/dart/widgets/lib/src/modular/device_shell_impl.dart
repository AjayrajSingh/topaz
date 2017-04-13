// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_context.fidl.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Called when [DeviceShell.initialize] occurs.
typedef void OnReady(
  UserProvider userProvider,
  DeviceContext deviceContext,
);

/// Implements a DeviceShell for receiving the services a [DeviceShell] needs to
/// operate.
class DeviceShellImpl extends DeviceShell {
  final DeviceContextProxy _deviceContextProxy = new DeviceContextProxy();
  final UserProviderProxy _userProviderProxy = new UserProviderProxy();

  /// Called when [initialize] occurs.
  final OnReady onReady;

  /// Called when the [DeviceShell] terminates.
  final VoidCallback onStop;

  /// Constructor.
  DeviceShellImpl({this.onReady, this.onStop});

  @override
  void initialize(
    InterfaceHandle<DeviceContext> deviceContext,
    InterfaceHandle<UserProvider> userProvider,
  ) {
    if (onReady != null) {
      _deviceContextProxy.ctrl.bind(deviceContext);
      _userProviderProxy.ctrl.bind(userProvider);
      onReady(_userProviderProxy, _deviceContextProxy);
    }
  }

  @override
  void terminate(void done()) {
    onStop?.call();
    _deviceContextProxy.ctrl.close();
    _userProviderProxy.ctrl.close();
    done();
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Called when [DeviceShell.initialize] occurs.
typedef void OnReady(
  UserProvider userProvider,
  DeviceShellContext deviceShellContext,
);

/// Implements a DeviceShell for receiving the services a [DeviceShell] needs to
/// operate.
class DeviceShellImpl extends DeviceShell {
  final DeviceShellContextProxy _deviceShellContextProxy =
      new DeviceShellContextProxy();
  final UserProviderProxy _userProviderProxy = new UserProviderProxy();

  /// Called when [initialize] occurs.
  final OnReady onReady;

  /// Called when the [DeviceShell] terminates.
  final VoidCallback onStop;

  /// Constructor.
  DeviceShellImpl({this.onReady, this.onStop});

  @override
  void initialize(
      InterfaceHandle<DeviceShellContext> deviceShellContextHandle) {
    if (onReady != null) {
      _deviceShellContextProxy.ctrl.bind(deviceShellContextHandle);
      _deviceShellContextProxy
          .getUserProvider(_userProviderProxy.ctrl.request());
      onReady(_userProviderProxy, _deviceShellContextProxy);
    }
  }

  @override
  void terminate(void done()) {
    onStop?.call();
    _userProviderProxy.ctrl.close();
    _deviceShellContextProxy.ctrl.close();
    done();
  }

  @override
  void getAuthenticationContext(
      String username, InterfaceRequest<AuthenticationContext> request) {
    request.close();
  }
}

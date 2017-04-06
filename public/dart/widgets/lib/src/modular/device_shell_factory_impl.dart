// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_context.fidl.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Called when [DeviceShellFactory.create] occurs.
typedef void OnReady(
  UserProvider userProvider,
  DeviceContext deviceContext,
);

/// Implements a DeviceShell for receiving the services a [DeviceShellFactory] needs to
/// operate.  When [create] is called, the services it receives are routed
/// by this class to the various classes which need them.
class DeviceShellFactoryImpl extends DeviceShellFactory {
  final DeviceContextProxy _deviceContextProxy = new DeviceContextProxy();
  final UserProviderProxy _userProviderProxy = new UserProviderProxy();
  final DeviceShellBinding _deviceShellBinding = new DeviceShellBinding();

  /// The [DeviceShell] to return in respose to [create]'s request.'
  final DeviceShell deviceShell;

  /// Called when [create] occurs.
  final OnReady onReady;

  /// Called when [deviceShell] stops.
  final VoidCallback onStop;

  /// Constructor.
  DeviceShellFactoryImpl({
    this.deviceShell,
    this.onReady,
    this.onStop,
  });

  @override
  void create(
    InterfaceHandle<DeviceContext> deviceContext,
    InterfaceHandle<UserProvider> userProvider,
    InterfaceRequest<DeviceShell> deviceShellRequest,
  ) {
    if (onReady != null) {
      _deviceContextProxy.ctrl.bind(deviceContext);
      _userProviderProxy.ctrl.bind(userProvider);
      onReady(_userProviderProxy, _deviceContextProxy);
    }

    if (deviceShell != null) {
      _deviceShellBinding.bind(deviceShell, deviceShellRequest);
    }
  }

  /// Should be called when [deviceShell] stops.
  void stop(void done()) {
    onStop?.call();
    _deviceContextProxy.ctrl.close();
    _userProviderProxy.ctrl.close();
    _deviceShellBinding.close();
    done();
  }
}

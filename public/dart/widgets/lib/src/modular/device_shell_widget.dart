// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'device_shell_impl.dart';
import 'device_shell_model.dart';

/// A wrapper widget intended to be the root of the application that is
/// a [DeviceShell].  Its main purpose is to hold the [ApplicationContext] and
/// [DeviceShell] instances so they aren't garbage collected.
/// For convienence, [advertise] does the advertising of the app as a
/// [DeviceShell] to the rest of the system via the [ApplicationContext].
/// Also for convienence, the [DeviceShellModel] given to this widget
/// will be made available to [child] and [child]'s descendants.
class DeviceShellWidget<T extends DeviceShellModel> extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [DeviceShell] services to.
  final ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();
  final DeviceShellBinding _binding = new DeviceShellBinding();

  /// The [DeviceShell] to [advertise].
  final DeviceShellImpl _deviceShell;

  /// The rest of the application.
  final Widget child;

  final T _deviceShellModel;

  /// Constructor.
  DeviceShellWidget({T deviceShellModel, this.child})
      : _deviceShellModel = deviceShellModel,
        _deviceShell = _createDeviceShell(deviceShellModel);

  @override
  Widget build(BuildContext context) => _deviceShellModel == null
      ? child
      : new ScopedModel<T>(model: _deviceShellModel, child: child);

  /// Advertises [_deviceShell] as a [DeviceShell] to the rest of the system via
  /// the [ApplicationContext].
  void advertise() => applicationContext.outgoingServices.addServiceForName(
        (InterfaceRequest<DeviceShell> request) =>
            _binding.bind(_deviceShell, request),
        DeviceShell.serviceName,
      );

  static DeviceShell _createDeviceShell(DeviceShellModel deviceShellModel) {
    DeviceShellImpl deviceShell;
    VoidCallback onStop = () {
      deviceShellModel?.onStop?.call();
      deviceShell.onStop();
    };
    deviceShell = new DeviceShellImpl(
      onReady: deviceShellModel?.onReady,
      onStop: onStop,
    );
    return deviceShell;
  }
}

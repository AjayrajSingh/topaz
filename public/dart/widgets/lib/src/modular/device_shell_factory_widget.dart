// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'device_shell_impl.dart';
import 'device_shell_factory_impl.dart';
import 'device_shell_factory_model.dart';

/// A wrapper widget intended to be the root of the application that is
/// a [DeviceShellFactory].  Its main purpose is to hold the [ApplicationContext] and
/// [DeviceShellFactory] instances so they aren't garbage collected.
/// For convienence, [advertise] does the advertising of the app as a
/// [DeviceShellFactory] to the rest of the system via the [ApplicationContext].
/// Also for convienence, the [DeviceShellFactoryModel] given to this widget
/// will be made available to [child] and [child]'s descendants.
class DeviceShellFactoryWidget<T extends DeviceShellFactoryModel>
    extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [DeviceShellFactory] services to.
  final ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();
  final DeviceShellFactoryBinding _binding = new DeviceShellFactoryBinding();

  /// The [DeviceShellFactory] to [advertise].
  DeviceShellFactoryImpl _deviceShellFactory;

  final T _deviceShellFactoryModel;

  /// The rest of the application.
  final Widget child;

  /// Constructor.
  DeviceShellFactoryWidget({T deviceShellFactoryModel, this.child})
      : _deviceShellFactoryModel = deviceShellFactoryModel {
    _deviceShellFactory = new DeviceShellFactoryImpl(
      deviceShell: new DeviceShellImpl(onStop: _handleStop),
      onReady: deviceShellFactoryModel?.onReady,
    );
  }

  @override
  Widget build(BuildContext context) => _deviceShellFactoryModel == null
      ? child
      : new ScopedModel<T>(
          model: _deviceShellFactoryModel,
          child: child,
        );

  /// Advertises [_deviceShellFactory] as a [DeviceShellFactory] to the rest of the system via
  /// the [ApplicationContext].
  void advertise() => applicationContext.outgoingServices.addServiceForName(
        (InterfaceRequest<DeviceShellFactory> request) =>
            _binding.bind(_deviceShellFactory, request),
        DeviceShellFactory.serviceName,
      );

  void _handleStop() {
    _deviceShellFactoryModel?.onStop?.call();
    _deviceShellFactory.onStop();
  }
}

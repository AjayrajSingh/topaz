// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_context.fidl.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart' show ScopedModel, ScopedModelDescendant;

/// The [Model] that provides a [DeviceContext] and [UserProvider].
class DeviceShellFactoryModel extends Model {
  DeviceContext _deviceContext;
  UserProvider _userProvider;

  /// The [DeviceContext] given to this app's [DeviceShellFactory].
  DeviceContext get deviceContext => _deviceContext;

  /// The [UserProvider] given to this app's [DeviceShellFactory].
  UserProvider get userProvider => _userProvider;

  /// Called when this app's [DeviceShellFactory] is given its [DeviceContext]
  /// and [UserProvider].
  void onReady(UserProvider userProvider, DeviceContext deviceContext) {
    _userProvider = userProvider;
    _deviceContext = deviceContext;
    notifyListeners();
  }

  /// Called when the app's [DeviceShell] stops.
  void onStop() => null;
}

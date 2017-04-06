// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:flutter/widgets.dart';

/// Implements a DeviceShell for receiving the services a [DeviceShell] needs to
/// operate.
class DeviceShellImpl extends DeviceShell {
  /// Called when the [DeviceShell] terminates.
  final VoidCallback onStop;

  /// Constructor.
  DeviceShellImpl({this.onStop});

  @override
  void terminate(void done()) {
    onStop?.call();
    done();
  }
}

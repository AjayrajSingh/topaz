// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:flutter/material.dart';

import 'bluetooth_model.dart';

/// Widget that displays bluetooth information, and allows users to
/// connect and disconnect from devices.
class BluetoothSettings extends StatelessWidget {
  /// Const constructor.
  const BluetoothSettings();

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<BluetoothSettingsModel>(
          builder: (
        BuildContext context,
        Widget child,
        BluetoothSettingsModel model,
      ) =>
              new LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      const Material(child: null)));
}

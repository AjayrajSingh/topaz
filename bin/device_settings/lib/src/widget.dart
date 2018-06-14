// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.settings/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'model.dart';

Widget _buildDeviceSettings(
    {@required DeviceSettingsModel model, @required double scale}) {
  return SettingsPage(scale: scale,
    sections: [_buildInfo(model, scale), _update(model, scale)]);
}

SettingsSection _buildInfo(DeviceSettingsModel model, double scale) {
    final buildSyncDate = SettingsText(
      text:'Source date: ${model.sourceDate}',
      scale: scale);
  return SettingsSection(
    title: 'Build Info',
    scale: scale,
    child: SettingsItemList(items:[buildSyncDate]));
}

SettingsSection _update(DeviceSettingsModel model, double scale) {
  final lastUpdatedText = SettingsText(
      text: model.lastUpdate == null
          ? 'This device has never been updated from settings'
          : 'This device was last updated on ${model.lastUpdate}.',
      scale: scale);

  final updateButton = SettingsButton(
    text: 'Check for updates',
    onTap: model.checkForUpdates,
    scale: scale,
  );

  return SettingsSection(
      title: 'Update',
      scale: scale,
      child: SettingsItemList(
        items: [lastUpdatedText, updateButton],
      ),
      topSection: false);
}

/// Widget that displays system settings such as update.
class DeviceSettings extends StatelessWidget {
  const DeviceSettings();

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<DeviceSettingsModel>(
          builder: (
        BuildContext context,
        Widget child,
        DeviceSettingsModel model,
      ) =>
              new LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      Material(
                          child: _buildDeviceSettings(
                              model: model,
                              scale:
                                  constraints.maxHeight > 360.0 ? 1.0 : 0.5))));
}

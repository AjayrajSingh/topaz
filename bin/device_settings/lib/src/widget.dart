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
  final settingsPage = SettingsPage(
      scale: scale,
      sections: [_buildInfo(model, scale), _update(model, scale)]);
  return model.showResetConfirmation
      ? Stack(children: [settingsPage, _buildResetBox(model, scale)])
      : settingsPage;
}

SettingsSection _buildInfo(DeviceSettingsModel model, double scale) {
  final buildSyncDate =
      SettingsText(text: 'Source date: ${model.sourceDate}', scale: scale);
  return SettingsSection(
      title: 'Build Info',
      scale: scale,
      child: SettingsItemList(items: [buildSyncDate]));
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

  final factoryResetButton = SettingsButton(
    text: 'Factory Reset',
    onTap: model.factoryReset,
    scale: scale,
  );

  return SettingsSection(
      title: 'Update',
      scale: scale,
      child: SettingsItemList(
        items: [lastUpdatedText, updateButton, factoryResetButton],
      ),
      topSection: false);
}

Widget _buildResetBox(DeviceSettingsModel model, double scale) {
  return SettingsPopup(
      onDismiss: model.cancelFactoryReset,
      child: Material(
          borderRadius: BorderRadius.all(Radius.circular(16.0 * scale)),
          color: Colors.white,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.8,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(16.0),
              child: SettingsSection(
                title: 'Factory Reset',
                scale: scale,
                child: Column(children: [
                  SettingsButton(
                    text: 'Reset',
                    scale: scale,
                    onTap: model.factoryReset,
                  ),
                  SettingsButton(
                    text: 'Cancel',
                    scale: scale,
                    onTap: model.cancelFactoryReset,
                  ),
                ]),
              ),
            ),
          )));
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

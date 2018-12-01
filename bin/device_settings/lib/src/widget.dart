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
  final widgets = <Widget>[
    SettingsPage(
        scale: scale,
        sections: [_buildInfo(model, scale), _update(model, scale)])
  ];

  if (model.showResetConfirmation) {
    widgets.add(_buildResetBox(model, scale));
  }

  if (model.channelPopupShowing.value) {
    widgets.add(_buildSelectPopup(model, scale));
  }

  return Stack(children: widgets);
}

SettingsSection _buildInfo(DeviceSettingsModel model, double scale) {
  final buildSyncDate =
      SettingsText(text: 'Source date: ${model.sourceDate}', scale: scale);
  final uptimeDuration = SettingsText(
      text: 'System uptime: ${uptimeToString(model.uptime)}', scale: scale);
  return SettingsSection(
      title: 'Build Info',
      scale: scale,
      child: SettingsItemList(
        items: [buildSyncDate, uptimeDuration],
        crossAxisAlignment: CrossAxisAlignment.start,
      ));
}

/// Converts from uptime duration to a user-readable string in the format HH:mm:ss.
String uptimeToString(Duration uptime) {
  // Uptime comes with 6 digits of milliseconds, remove since we don't care to show it.
  return uptime.toString().split('.')[0];
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

  final currentSourceText = SettingsText(
      scale: scale, text: 'Current source: ${model.selectedChannels}');

  final changeSourceButton = SettingsButton(
    text: 'Change source',
    onTap: () => model.channelPopupShowing.value = true,
    scale: scale,
  );

  return SettingsSection(
      title: 'Update',
      scale: scale,
      child: SettingsItemList(
        items: [
          lastUpdatedText,
          updateButton,
          currentSourceText,
          changeSourceButton,
          factoryResetButton
        ],
      ),
      topSection: false);
}

Widget _buildSelectPopup(DeviceSettingsModel model, double scale) {
  return SettingsPopup(
      onDismiss: () => model.channelPopupShowing.value = false,
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
                  title: 'Select channel',
                  scale: scale,
                  child: Column(
                      children: model.channels
                          .map((channel) => SettingsButton(
                              onTap: () => model.selectChannel(channel),
                              scale: scale,
                              text: '${channel?.id ?? 'None'}'))
                          .toList()
                            ..add(SettingsButton(
                                onTap: () => model.selectChannel(null),
                                scale: scale,
                                text: 'None')))),
            ),
          )));
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
  Widget build(BuildContext context) => Provide<DeviceSettingsModel>(
          builder: (
        BuildContext context,
        Widget child,
        DeviceSettingsModel model,
      ) =>
              LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      Material(
                          child: _buildDeviceSettings(
                              model: model,
                              scale:
                                  constraints.maxHeight > 360.0 ? 1.0 : 0.5))));
}

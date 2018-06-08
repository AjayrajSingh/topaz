// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_bluetooth_control/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.settings/widgets.dart';
import 'package:flutter/material.dart';

import 'bluetooth_model.dart';

/// Widget that displays bluetooth information, and allows users to
/// connect and disconnect from devices.
class BluetoothSettings extends StatelessWidget {
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
                      Material(
                          child: _buildBluetoothSettings(
                              model: model,
                              scale:
                                  constraints.maxHeight > 360.0 ? 1.0 : 0.5))));
}

typedef BluetoothSettingsSectionBuilder = SettingsSection Function(
    BluetoothSettingsModel model, double scale);

Widget _buildBluetoothSettings(
    {@required BluetoothSettingsModel model, @required double scale}) {
  if (model.activeAdapter == null) {
    return SettingsPage(
      scale: scale,
      sections: [
        SettingsSection.error(
          scale: scale,
          description: 'No bluetooth adapters were found',
        )
      ],
    );
  }

  return SettingsPage(
    scale: scale,
    sections: [_connectedDevices, _availableDevices, _adapters, _settings]
        .map((BluetoothSettingsSectionBuilder sectionBuilder) =>
            sectionBuilder(model, scale))
        .toList(),
  );
}

SettingsSection _settings(BluetoothSettingsModel model, double scale) {
  final discoverableSetting = SettingsSwitchTile(
    scale: scale,
    state: model.discoverable,
    text: 'Discoverable',
    onSwitch: (value) => model.setDiscoverable(discoverable: value),
  );

  return SettingsSection(
      title: 'Settings',
      scale: scale,
      child: SettingsItemList(
        items: [discoverableSetting],
      ));
}

SettingsSection _connectedDevices(BluetoothSettingsModel model, double scale) {
  if (model.connectedDevices.isEmpty) {
    return SettingsSection.empty();
  }

  return SettingsSection(
      title: 'Connected devices',
      scale: scale,
      child: SettingsItemList(
        items:
            model.connectedDevices.map((device) => _deviceTile(device, scale)),
      ));
}

SettingsSection _availableDevices(BluetoothSettingsModel model, double scale) {
  if (model.availableDevices.isEmpty) {
    return SettingsSection.error(
      scale: scale,
      title: _availableDevicesTitle,
      description: 'No bluetooth devices available to connect',
    );
  }

  return SettingsSection(
      title: _availableDevicesTitle,
      scale: scale,
      child: SettingsItemList(
        items:
            model.availableDevices.map((device) => _deviceTile(device, scale)),
      ));
}

/// Section containing the list of adapters, both active and not.
///
/// In future, this should probably be moved somewhere more hidden, as in the
/// vast majority of cases, thre should be either one or no adapters.
SettingsSection _adapters(BluetoothSettingsModel model, double scale) {
  final _adapters = [_activeAdapterTile(model.activeAdapter, scale)]..addAll(
      model.inactiveAdapters.map((adapter) => _adapterTile(adapter, scale)));

  return SettingsSection(
    title: 'Adapters',
    scale: scale,
    child: SettingsItemList(items: _adapters),
  );
}

SettingsTile _deviceTile(RemoteDevice device, double scale) {
  return SettingsTile(
    text: device.name,
    description: 'ID: ${device.identifier}',
    iconData: device.connected ? Icons.bluetooth_connected : Icons.bluetooth,
    scale: scale,
  );
}

SettingsTile _adapterTile(AdapterInfo adapter, double scale) {
  return SettingsTile(
    text: adapter.identifier,
    iconData: Icons.bluetooth_disabled,
    scale: scale,
  );
}

SettingsTile _activeAdapterTile(AdapterInfo adapter, double scale) {
  return SettingsTile(
    text: adapter.identifier,
    description: 'connected',
    iconData: Icons.bluetooth_searching,
    scale: scale,
  );
}

const String _availableDevicesTitle = 'Available Devices';

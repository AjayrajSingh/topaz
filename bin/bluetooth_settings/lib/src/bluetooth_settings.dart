// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_bluetooth_control/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.settings/widgets.dart';
import 'package:lib.widgets/model.dart';

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

  final page = SettingsPage(
    scale: scale,
    sections: [_connectedDevices, _availableDevices, _adapters, _settings]
        .map((BluetoothSettingsSectionBuilder sectionBuilder) =>
            sectionBuilder(model, scale))
        .toList(),
  );

  return model.pairingStatus != null
      ? Stack(children: [page, _buildPairingPopup(model.pairingStatus, scale)])
      : page;
}

Widget _buildPairingPopup(PairingStatus status, double scale) {
  return SettingsPopup(
      onDismiss: () {},
      child: Material(
          color: Colors.white,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(padding: EdgeInsets.only(top: 16.0 * scale)),
                Text(
                  'Type ${status.displayedPassKey} on your device',
                  style: _titleTextStyle(scale),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 400.0 * scale),
                  child: Container(
                    padding: EdgeInsets.only(top: 16.0 * scale),
                    child: Text(
                      _keys(status.digitsEntered),
                      style: _textStyle(scale),
                    ),
                  ),
                ),
              ],
            ),
          )));
}

String _keys(int keysEntered) {
  var s = StringBuffer();

  for (int i = 0; i < keysEntered; i++) {
    s.write('*');
  }
  return s.toString();
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
  if (model.knownDevices.isEmpty) {
    return SettingsSection.empty();
  }
  return SettingsSection(
      title: 'Known devices',
      scale: scale,
      child: SettingsItemList(
          items: model.knownDevices.map((device) =>
              _deviceTile(device, scale, () => model.disconnect(device)))));
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
        items: model.availableDevices.map((device) =>
            _deviceTile(device, scale, () => model.connect(device))),
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

SettingsTile _deviceTile(
    RemoteDevice device, double scale, VoidCallback onTap) {
  return SettingsTile(
    text: device.name ?? device.address,
    description: device.connected ? 'Paired' : 'ID: ${device.identifier}',
    onTap: onTap,
    iconData: _icon(device),
    scale: scale,
  );
}

IconData _icon(RemoteDevice device) {
  if (device.appearance == Appearance.hidKeyboard) {
    return Icons.keyboard;
  }
  return device.connected ? Icons.bluetooth_connected : Icons.bluetooth;
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

TextStyle _titleTextStyle(double scale) => TextStyle(
      color: Colors.grey[900],
      fontSize: 48.0 * scale,
      fontWeight: FontWeight.w200,
    );

TextStyle _textStyle(double scale) => TextStyle(
      color: Colors.grey[900],
      fontSize: 36.0 * scale,
      fontWeight: FontWeight.w200,
    );

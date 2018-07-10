// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_bluetooth_control/fidl.dart' as bt_ctl;
import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

import 'models/settings_model.dart';

class _SettingsScaffold extends StatelessWidget {
  Widget _getDiscoveredDevicesWidget(
      BuildContext context, SettingsModel model) {
    if (model.discoveredDevices.isEmpty) {
      return const Center(child: const Text('No devices found'));
    }

    return new ListView(
        children: ListTile
            .divideTiles(
                context: context,
                tiles:
                    model.discoveredDevices.map((bt_ctl.RemoteDevice device) {
                  return new ListTile(
                      title: new Text(device.name ?? '(unknown)'),
                      subtitle: new Text(device.address));
                }))
            .toList());
  }

  Widget _getPopUpMenuButton(SettingsModel model) {
    return new PopupMenuButton<int>(
        onSelected: (int index) => model.setActiveAdapterByIndex(index),
        itemBuilder: (BuildContext context) {
          int index = 0;
          return model.adapters
              .map((bt_ctl.AdapterInfo adapter) => new PopupMenuItem<int>(
                    enabled: !model.isActiveAdapter(adapter.identifier),
                    value: index++,
                    child: new Text(adapter.address +
                        (model.isActiveAdapter(adapter.identifier)
                            ? ' (active)'
                            : '')),
                  ))
              .toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<SettingsModel>(builder: (
      BuildContext context,
      Widget child,
      SettingsModel model,
    ) {
      return new Scaffold(
        appBar: new AppBar(
          title: new Text(
              'Bluetooth Settings (${model.activeAdapterDescription})'),
          bottom: model.isDiscovering
              ? const PreferredSize(
                  child: const LinearProgressIndicator(),
                  preferredSize: Size.zero)
              : null,
          actions: <Widget>[
            new IconButton(
                tooltip: 'Discover Bluetooth devices',
                onPressed:
                    (model.hasActiveAdapter && !model.isDiscoveryRequestPending)
                        ? () => model.toggleDiscovery()
                        : null,
                icon: const Icon(Icons.bluetooth_searching)),
            _getPopUpMenuButton(model),
          ],
        ),
        body: _getDiscoveredDevicesWidget(context, model),
      );
    });
  }
}

/// Root Widget of the Settings example module.
class SettingsScreen extends StatelessWidget {
  /// Constructor
  const SettingsScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new _SettingsScaffold();
  }
}

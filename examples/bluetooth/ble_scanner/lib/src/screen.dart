// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

import 'models/ble_scanner_model.dart';
import 'widgets/scan_filter_button.dart';
import 'widgets/scan_results_widget.dart';

/// Root Widget of the BLE Scanner module.
class BLEScannerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<BLEScannerModel>(builder: (
      BuildContext context,
      Widget child,
      BLEScannerModel moduleModel,
    ) {
      return new Scaffold(
          appBar: new AppBar(
              title: const Text('BLE Scanner'),
              bottom: moduleModel.isScanning
                  ? const PreferredSize(
                      child: const LinearProgressIndicator(),
                      preferredSize: Size.zero)
                  : null,
              actions: <Widget>[
                new IconButton(
                    tooltip: 'Scan for BLE devices',
                    onPressed: moduleModel.isScanRequestPending
                        ? null
                        : () => moduleModel.toggleScan(),
                    icon: const Icon(Icons.bluetooth_searching)),
                new ScanFilterButton(),
              ]),
          body: new ScanResultsWidget());
    });
  }
}

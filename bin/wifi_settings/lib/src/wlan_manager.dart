// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.settings/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'fuchsia/access_point.dart';
import 'fuchsia/wifi_settings_model.dart';

TextStyle _titleTextStyle(double scale) => TextStyle(
      color: Colors.grey[900],
      fontSize: 48.0 * scale,
      fontWeight: FontWeight.w200,
    );

TextStyle _textStyle(double scale) => TextStyle(
      color: Colors.grey[900],
      fontSize: 24.0 * scale,
      fontWeight: FontWeight.w200,
    );

/// Displays WLAN info.
class WlanManager extends StatelessWidget {
  /// Const constructor.
  const WlanManager();

  @override
  Widget build(BuildContext context) =>
      ScopedModelDescendant<WifiSettingsModel>(
          builder: (
        BuildContext context,
        Widget child,
        WifiSettingsModel model,
      ) =>
              LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      Material(child: _getCurrentWidget(model, constraints))));

  Widget _getCurrentWidget(
      WifiSettingsModel model, BoxConstraints constraints) {
    double scale = constraints.maxHeight > 360.0 ? 1.0 : 0.5;

    Widget widget;
    if (!model.hasWifiAdapter) {
      widget = SettingsPage(
        scale: scale,
        sections: [
          SettingsSection.error(
              description: 'No wireless adapters are available on this device',
              scale: scale)
        ],
      );
    } else if (model.loading) {
      widget = SettingsPage(scale: scale, isLoading: true);
    } else if (model.connecting || model.connectedAccessPoint != null) {
      widget = _buildCurrentNetwork(model, scale);
    } else if ((model.selectedAccessPoint?.isSecure ?? false) &&
        !model.connecting) {
      widget = new Stack(children: <Widget>[
        _buildAvailableNetworks(model, scale),
        _buildPasswordBox(model, scale),
      ]);
    } else {
      widget = _buildAvailableNetworks(model, scale);
    }

    return widget;
  }

  Widget _buildCurrentNetwork(WifiSettingsModel model, double scale) {
    final AccessPoint accessPoint =
        model.connectedAccessPoint ?? model.selectedAccessPoint;

    List<Widget> widgets = [
      Padding(padding: EdgeInsets.only(top: 16.0 * scale)),
      SettingsTile(
          scale: scale,
          assetUrl: accessPoint.url,
          text: accessPoint.name,
          description: model.connectionStatusMessage),
    ];

    if (model.connectedAccessPoint != null) {
      widgets.addAll([
        Padding(padding: EdgeInsets.only(top: 8.0 * scale)),
        SettingsButton(
          scale: scale,
          text: 'Disconnect from current network',
          onTap: model.disconnect,
        )
      ]);
    }

    return SettingsPage(
      title: 'Current Network',
      scale: scale,
      sections: [
        SettingsSection(
            scale: scale,
            child: Column(
              children: widgets,
              crossAxisAlignment: CrossAxisAlignment.start,
            ))
      ],
    );
  }

  Widget _buildAvailableNetworks(WifiSettingsModel model, double scale) {
    if (model.accessPoints == null || model.accessPoints.isEmpty) {
      return SettingsPage(
        scale: scale,
        title: 'Scanning...',
        isLoading: true,
      );
    }

    return SettingsPage(
      scale: scale,
      title: 'Available Networks (${model.accessPoints.length} found)',
      sections: [
        SettingsSection(
          scale: scale,
          child: SettingsItemList(
              items: model.accessPoints.map((AccessPoint ap) => SettingsTile(
                    scale: scale,
                    text: ap.name,
                    assetUrl: ap.url,
                    description: ap.name == model.failedAccessPoint?.name
                        ? model.connectionResultMessage
                        : null,
                    onTap: () {
                      model.selectedAccessPoint = ap;
                    },
                  ))),
        )
      ],
    );
  }

  Widget _buildPasswordBox(WifiSettingsModel model, double scale) {
    return SettingsPopup(
        onDismiss: model.onPasswordCanceled,
        child: Material(
            color: Colors.white,
            child: FractionallySizedBox(
              widthFactor: 0.8,
              heightFactor: 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(padding: EdgeInsets.only(top: 16.0 * scale)),
                  Text(
                    'Enter password:',
                    style: _titleTextStyle(scale),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 400.0 * scale),
                    child: Container(
                      padding: EdgeInsets.only(top: 32.0 * scale),
                      child: TextField(
                        obscureText: true,
                        autofocus: true,
                        style: _textStyle(scale),
                        onSubmitted: model.onPasswordEntered,
                      ),
                    ),
                  ),
                ],
              ),
            )));
  }
}

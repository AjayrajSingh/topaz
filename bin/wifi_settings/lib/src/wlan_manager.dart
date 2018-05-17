// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.settings/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'fuchsia/access_point.dart';
import 'fuchsia/wifi_settings_model.dart';

TextStyle _titleTextStyle(double scale) => new TextStyle(
      color: Colors.grey[900],
      fontSize: 48.0 * scale,
      fontWeight: FontWeight.w200,
    );

TextStyle _textStyle(double scale) => new TextStyle(
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
      new ScopedModelDescendant<WifiSettingsModel>(
          builder: (
        BuildContext context,
        Widget child,
        WifiSettingsModel model,
      ) =>
              new LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      new Material(
                          child: _getCurrentWidget(model, constraints))));

  Widget _getCurrentWidget(
      WifiSettingsModel model, BoxConstraints constraints) {
    double scale = constraints.maxHeight > 360.0 ? 1.0 : 0.5;

    Widget widget;

    if (model.loading) {
      widget = new SettingsPage(scale: scale, isLoading: true);
    } else if (model.connecting || model.connectedAccessPoint != null) {
      widget = _padded(_buildCurrentNetwork(model, scale));
    } else if ((model.selectedAccessPoint?.isSecure ?? false) &&
        !model.connecting) {
      widget = new Stack(children: <Widget>[
        _padded(_buildAvailableNetworks(model, scale)),
        _buildPasswordBox(model, scale),
      ]);
    } else {
      widget = _padded(_buildAvailableNetworks(model, scale));
    }

    return widget;
  }

  Widget _padded(Widget child) {
    return new Container(padding: const EdgeInsets.all(12.0), child: child);
  }

  Widget _buildCurrentNetwork(WifiSettingsModel model, double scale) {
    List<Widget> widgets = <Widget>[
      new Text('Current Network', style: _titleTextStyle(scale)),
      new Padding(padding: new EdgeInsets.only(top: 16.0 * scale)),
      new AccessPointWidget(
          scale: scale,
          accessPoint: model.connectedAccessPoint ?? model.selectedAccessPoint,
          status: model.connectionStatusMessage),
    ];

    if (model.connectedAccessPoint != null) {
      widgets.addAll(<Widget>[
        new Padding(padding: new EdgeInsets.only(top: 16.0 * scale)),
        new FlatButton(
            child: new Text('Disconnect', style: _textStyle(scale)),
            onPressed: model.disconnect)
      ]);
    }

    return new Center(
        child: new FractionallySizedBox(
            widthFactor: 0.4,
            child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widgets)));
  }

  Widget _buildAvailableNetworks(WifiSettingsModel model, double scale) {
    if (model.accessPoints == null || model.accessPoints.isEmpty) {
      return new SettingsPage(
        scale: scale,
        title: 'Scanning...',
        isLoading: true,
      );
    }

    return new Column(mainAxisSize: MainAxisSize.max, children: <Widget>[
      new Text('Available Networks (${model.accessPoints.length} found)',
          style: _titleTextStyle(scale)),
      new Expanded(
          child: new ListView(
        padding: new EdgeInsets.all(16.0 * scale),
        children: model.accessPoints
            .map((AccessPoint accessPoint) => new AccessPointWidget(
                scale: scale,
                accessPoint: accessPoint,
                status: accessPoint.name == model.failedAccessPoint?.name
                    ? model.connectionResultMessage
                    : null,
                onTap: () {
                  model.selectedAccessPoint = accessPoint;
                }))
            .toList(),
      ))
    ]);
  }

  Widget _buildPasswordBox(WifiSettingsModel model, double scale) {
    Widget passwordBox = new Center(
        child: new Material(
            color: Colors.white,
            child: new FractionallySizedBox(
              widthFactor: 0.8,
              heightFactor: 0.5,
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Padding(padding: new EdgeInsets.only(top: 16.0 * scale)),
                  new Text(
                    'Enter password:',
                    style: _titleTextStyle(scale),
                  ),
                  new ConstrainedBox(
                    constraints: new BoxConstraints(maxWidth: 400.0 * scale),
                    child: new Container(
                      padding: new EdgeInsets.only(top: 32.0 * scale),
                      child: new TextField(
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

    Widget overlayCancel = new Opacity(
        opacity: 0.4,
        child: new Material(
            color: Colors.grey[900],
            child: new GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                model.onPasswordCanceled();
              },
            )));

    return new Stack(
      children: <Widget>[
        overlayCancel,
        passwordBox,
      ],
    );
  }
}

/// Widget that displays a single network.
class AccessPointWidget extends StatelessWidget {
  /// The network to be shown.
  final AccessPoint accessPoint;

  /// The connection status to be displayed for the network, if applicable.
  final String status;

  /// Callback to run when the network is tapped
  final VoidCallback onTap;

  /// Scaling factor to render widget
  final double scale;

  /// Builds a new access point.
  const AccessPointWidget(
      {@required this.accessPoint, this.status, this.onTap, this.scale});

  @override
  Widget build(BuildContext context) {
    return new InkWell(
        onTap: onTap,
        child: new Container(
            height: 64.0 * scale,
            width: 480.0 * scale,
            child: new Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[_buildLogo(), _buildText()],
            )));
  }

  Widget _buildLogo() {
    return new Container(
        padding: new EdgeInsets.only(
          right: 16.0 * scale,
        ),
        child: new Image.asset(
          accessPoint.url,
          height: 48.0 * scale,
          width: 48.0 * scale,
        ));
  }

  Widget _buildText() {
    final Text apName = new Text(accessPoint.name, style: _textStyle(scale));

    if (status == null) {
      return apName;
    }

    return new Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[apName, new Text(status, style: _textStyle(scale))],
    );
  }
}

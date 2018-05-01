// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'fuchsia/access_point.dart';
import 'fuchsia/wifi_settings_model.dart';

const TextStyle _kTextStyle = const TextStyle(
  color: Colors.white,
  fontSize: 16.0,
);

/// Displays WLAN info.
class WlanInfo extends StatelessWidget {
  /// Const constructor.
  const WlanInfo();

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<WifiSettingsModel>(
        builder: (
          BuildContext context,
          Widget child,
          WifiSettingsModel model,
        ) {
          if (_hasConnectionResult(model)) {
            return new Center(
              child: new Text(
                model.connectionResultMessage,
                style: _kTextStyle,
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_isConnecting(model)) {
            return new Center(
              child: new Text(
                'Connecting to: ${model.selectedAccessPoint.name}',
                style: _kTextStyle,
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_isSecureNetworkSelected(model)) {
            return new Center(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Enter password:',
                    style: _kTextStyle,
                  ),
                  new ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200.0),
                    child: new Container(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: new TextField(
                        obscureText: true,
                        autofocus: true,
                        onSubmitted: model.onPasswordEntered,
                        style: _kTextStyle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (_areNetworksAvailable(model)) {
            return new Column(
              children: model.accessPoints
                  .map(
                    (AccessPoint accessPoint) => new Expanded(
                          child: new Material(
                            color: Colors.grey[900],
                            child: new InkWell(
                              onTap: () {
                                model.selectedAccessPoint = accessPoint;
                              },
                              highlightColor: Colors.grey[300],
                              splashColor: Colors.grey[50],
                              child: new Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  new Container(
                                    padding: const EdgeInsets.only(
                                      right: 8.0,
                                    ),
                                    child: new Image.asset(
                                      accessPoint.url,
                                      height: 20.0,
                                      width: 20.0,
                                    ),
                                  ),
                                  new Expanded(
                                    child: new Text(
                                      accessPoint.name,
                                      overflow: TextOverflow.fade,
                                      style: _kTextStyle,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  )
                  .toList(),
            );
          }

          if (_isInError(model)) {
            return new Center(
              child: new Text(
                model.errorMessage,
                textAlign: TextAlign.center,
                style: _kTextStyle,
              ),
            );
          }

          return new Center(
            child: new Container(
              width: 64.0,
              height: 64.0,
              child: new FuchsiaSpinner(),
            ),
          );
        },
      );

  bool _hasConnectionResult(WifiSettingsModel model) =>
      model.connectionResultMessage != null;

  bool _isInError(WifiSettingsModel model) => model.errorMessage != null;

  bool _areNetworksAvailable(WifiSettingsModel model) =>
      model.accessPoints.isNotEmpty && model.errorMessage == null;

  bool _isSecureNetworkSelected(WifiSettingsModel model) =>
      model.selectedAccessPoint?.isSecure ?? false;

  bool _isConnecting(WifiSettingsModel model) =>
      model.selectedAccessPoint != null &&
      (!model.selectedAccessPoint.isSecure || model.passwordEntered);
}

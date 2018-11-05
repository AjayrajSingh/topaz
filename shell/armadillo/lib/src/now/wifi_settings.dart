// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/modular.dart';

import 'context_model.dart';

const double _kMousePointerElevation = 800.0;
const double _kIndicatorElevation = _kMousePointerElevation - 1.0;

/// Manages Wifi network discovery and connectivity.
class WifiSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new Stack(children: <Widget>[
        new ScopedModelDescendant<ContextModel>(
            builder: (
          BuildContext context,
          Widget child,
          ContextModel contextModel,
        ) =>
                new Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent pointerDownEvent) {
                    contextModel.isWifiManagerShowing = false;
                  },
                )),
        new ScopedModelDescendant<SessionShellModel>(
          builder: (
            BuildContext context,
            Widget child,
            SessionShellModel sessionShellModel,
          ) =>
              new Center(
                child: new FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 0.5,
                  child: new Container(
                    margin: const EdgeInsets.all(8.0),
                    child: new PhysicalModel(
                      color: Colors.grey[900],
                      elevation: _kIndicatorElevation,
                      borderRadius: new BorderRadius.circular(4.0),
                      child: new ApplicationWidget(
                        url: 'wifi_settings',
                        launcher: sessionShellModel.startupContext.launcher,
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ]);
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'launcher_toggle.dart';
import 'status_tray.dart';
import 'window_playground.dart';

void main() {
  runApp(
    new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        new Image.asset(
          'packages/capybara_user_shell/res/background.jpg',
          fit: BoxFit.cover,
        ),
        new Column(
          children: <Widget>[
            new Expanded(
              child: new WindowPlaygroundWidget(),
            ),
            new Container(
              height: 48.0,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
              ),
              decoration: const BoxDecoration(
                color: Colors.black87,
              ),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new LauncherToggleWidget(),
                  new StatusTrayWidget(isStandalone: false),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

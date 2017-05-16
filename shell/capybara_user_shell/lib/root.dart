// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'launcher.dart';
import 'launcher_toggle.dart';
import 'status_tray.dart';
import 'window_playground.dart';

/// Base widget of the user shell.
class RootWidget extends StatefulWidget {
  @override
  _RootState createState() => new _RootState();
}

class _RootState extends State<RootWidget> {
  final GlobalKey<LauncherToggleState> _launcherToggleKey =
      new GlobalKey<LauncherToggleState>();

  /// Whether the Launcher should be displayed.
  bool _isLauncherShowing = false;

  /// Controls the visibility of the launcher and the state of its toggle.
  void _showLauncher(bool show) {
    setState(() {
      _isLauncherShowing = show;
    });
    _launcherToggleKey.currentState.toggled = show;
  }

  @override
  Widget build(BuildContext context) {
    return new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // 1 - Desktop background image.
        new Image.asset(
          'packages/capybara_user_shell/res/background.jpg',
          fit: BoxFit.cover,
        ),

        // 2 - The space where windows live.
        new WindowPlaygroundWidget(),

        // 3 - Launcher, overlaid on top of all the windows.
        // TODO(pylaligand): Offstage still lays its children out, consider
        // editing the list directly instead.
        new Offstage(
          offstage: !_isLauncherShowing,
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              // Dismiss the launcher if a click occurs outside of its bounds.
              new GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showLauncher(false),
              ),
              new Center(
                child: new Launcher(),
              ),
            ],
          ),
        ),

        // 4 - The bottom bar.
        new Positioned(
          left: 0.0,
          right: 0.0,
          bottom: 0.0,
          child: new Container(
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
                new LauncherToggleWidget(
                  key: _launcherToggleKey,
                  callback: _showLauncher,
                ),
                new StatusTrayWidget(isStandalone: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

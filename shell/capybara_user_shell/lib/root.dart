// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'launcher.dart';
import 'launcher_toggle.dart';
import 'status_tray.dart';
import 'widgets/system_overlay.dart';
import 'window_playground.dart';

/// Base widget of the user shell.
class RootWidget extends StatefulWidget {
  @override
  _RootState createState() => new _RootState();
}

class _RootState extends State<RootWidget> with TickerProviderStateMixin {
  final GlobalKey<LauncherToggleState> _launcherToggleKey =
      new GlobalKey<LauncherToggleState>();
  final GlobalKey<SystemOverlayState> _launcherOverlayKey =
      new GlobalKey<SystemOverlayState>();

  final Tween<double> _launcherScaleTween =
      new Tween<double>(begin: 0.9, end: 1.0);
  final Tween<double> _launcherOpacityTween =
      new Tween<double>(begin: 0.0, end: 1.0);

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
        new SystemOverlay(
          key: _launcherOverlayKey,
          builder: (Animation<double> animation) => new Center(
                child: new FadeTransition(
                    opacity: _launcherScaleTween.animate(animation),
                    child: new ScaleTransition(
                      scale: _launcherOpacityTween.animate(animation),
                      child: new Launcher(),
                    )),
              ),
          callback: (bool visible) {
            _launcherToggleKey.currentState.toggled = visible;
          },
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
                  callback: (bool toggled) =>
                      _launcherOverlayKey.currentState.visible = toggled,
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

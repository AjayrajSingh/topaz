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

class _RootState extends State<RootWidget> with TickerProviderStateMixin {
  final GlobalKey<LauncherToggleState> _launcherToggleKey =
      new GlobalKey<LauncherToggleState>();

  /// Whether the Launcher should be displayed.
  bool _isLauncherShowing = false;

  AnimationController _controller;
  Animation<double> _launcherAnimation;

  final Tween<double> _launcherScaleTween =
      new Tween<double>(begin: 0.9, end: 1.0);
  final Tween<double> _launcherOpacityTween =
      new Tween<double>(begin: 0.0, end: 1.0);

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(
        duration: const Duration(milliseconds: 150), vsync: this);
    _launcherAnimation = new CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Controls the visibility of the launcher and the state of its toggle.
  void _showLauncher(bool show) {
    if (show == _isLauncherShowing) {
      return;
    }
    setState(() {
      _isLauncherShowing = show;
      _isLauncherShowing ? _controller.forward() : _controller.reverse();
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
        new AnimatedBuilder(
          animation: _launcherAnimation,
          builder: (BuildContext context, Widget child) => new Offstage(
                // Only include the Launcher if it is actually visible.
                offstage: _launcherAnimation.isDismissed,
                child: child,
              ),
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              // Dismiss the launcher if a click occurs outside of its bounds.
              new GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showLauncher(false),
              ),
              new Center(
                child: new FadeTransition(
                    opacity: _launcherOpacityTween.animate(_launcherAnimation),
                    child: new ScaleTransition(
                      scale: _launcherScaleTween.animate(_launcherAnimation),
                      child: new Launcher(),
                    )),
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

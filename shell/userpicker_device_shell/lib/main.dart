// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/modular.dart';

import 'authentication_overlay.dart';
import 'authentication_overlay_model.dart';
import 'authentication_context_impl.dart';
import 'child_constraints_changer.dart';
import 'constraints_model.dart';
import 'debug_text.dart';
import 'memory_indicator.dart';
import 'user_picker_device_shell_screen.dart';
import 'soft_keyboard_container_impl.dart';
import 'user_picker_device_shell_model.dart';

/// Set to true to have this BaseShell provide IME services.
const bool _kAdvertiseImeService = false;

/// Set to true to enable the performance overlay.
const bool _kShowPerformanceOverlay = false;

void main() {
  setupLogger(name: 'userpicker_device_shell');
  GlobalKey screenManagerKey = new GlobalKey();
  ConstraintsModel constraintsModel = new ConstraintsModel();
  UserPickerDeviceShellModel model = new UserPickerDeviceShellModel();
  AuthenticationOverlayModel authenticationOverlayModel =
      new AuthenticationOverlayModel();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  SoftKeyboardContainerImpl softKeyboardContainerImpl = _kAdvertiseImeService
      ? new SoftKeyboardContainerImpl(
          child: new ApplicationWidget(
            url: 'latin-ime',
            launcher: applicationContext.launcher,
          ),
        )
      : null;

  Widget mainWidget = new Stack(
    fit: StackFit.passthrough,
    children: <Widget>[
      new UserPickerDeviceShellScreen(
        key: screenManagerKey,
        launcher: applicationContext.launcher,
      ),
      new ScopedModel<AuthenticationOverlayModel>(
        model: authenticationOverlayModel,
        child: new AuthenticationOverlay(),
      ),
    ],
  );

  GlobalKey<ChildConstraintsChangerState> childConstraintsChangerKey =
      new GlobalKey<ChildConstraintsChangerState>();
  Widget app = new ChildConstraintsChanger(
    key: childConstraintsChangerKey,
    constraintsModel: constraintsModel,
    child: softKeyboardContainerImpl?.wrap(child: mainWidget) ?? mainWidget,
  );

  List<OverlayEntry> overlays = <OverlayEntry>[
    new OverlayEntry(
      builder: (BuildContext context) => new MediaQuery(
            data: const MediaQueryData(),
            child: new FocusScope(
              node: new FocusScopeNode(),
              autofocus: true,
              child: _kShowPerformanceOverlay
                  ? _buildPerformanceOverlay(child: app)
                  : app,
            ),
          ),
    ),
    new OverlayEntry(
      builder: (_) => new Align(
            alignment: FractionalOffset.topCenter,
            child: new DebugText(),
          ),
    ),
  ];

  /// As querying free memory is expensive, only do in debug mode.
  assert(() {
    overlays.add(
      new OverlayEntry(
        builder: (_) => new Align(
              alignment: FractionalOffset.topLeft,
              child: new Container(
                margin: const EdgeInsets.all(8.0),
                child: new PhysicalModel(
                  color: Colors.grey[900],
                  elevation: 799.0, // Mouse pointer is at 800.0.
                  borderRadius: new BorderRadius.circular(8.0),
                  child: new Container(
                    padding: const EdgeInsets.all(8.0),
                    child: new MemoryIndicator(),
                  ),
                ),
              ),
            ),
      ),
    );
    return true;
  });

  DeviceShellWidget<UserPickerDeviceShellModel> deviceShellWidget =
      new DeviceShellWidget<UserPickerDeviceShellModel>(
    applicationContext: applicationContext,
    softKeyboardContainer: softKeyboardContainerImpl,
    deviceShellModel: model,
    authenticationContext: new AuthenticationContextImpl(
      onStartOverlay: authenticationOverlayModel.onStartOverlay,
      onStopOverlay: authenticationOverlayModel.onStopOverlay,
    ),
    child: new Overlay(initialEntries: overlays),
  );

  runApp(new CheckedModeBanner(child: deviceShellWidget));

  constraintsModel.load(rootBundle);
  deviceShellWidget.advertise();
  softKeyboardContainerImpl?.advertise();
  RawKeyboard.instance.addListener((RawKeyEvent event) {
    final bool isDown = event is RawKeyDownEvent;
    final RawKeyEventDataFuchsia data = event.data;
    // Flip through constraints with Ctrl-`.
    // Trigger on up to avoid repeats.
    if (!isDown &&
            (data.codePoint == 96) && // `
            (data.modifiers & 24) != 0 // Ctrl down
        ) {
      childConstraintsChangerKey.currentState.toggleConstraints();
    }
  });
}

Widget _buildPerformanceOverlay({Widget child}) => new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        new Positioned(
          bottom: 0.0,
          left: 0.0,
          right: 0.0,
          child: new IgnorePointer(child: new PerformanceOverlay.allEnabled()),
        ),
        new Align(
          alignment: FractionalOffset.bottomCenter,
          child: new Text(
            'Base shell performance',
            style: new TextStyle(color: Colors.black),
          ),
        ),
      ],
    );

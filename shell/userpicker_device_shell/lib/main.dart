// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:lib.app.dart/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.netstack.fidl/netstack.fidl.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.wlan.fidl/wlan_service.fidl.dart';

import 'authentication_context_impl.dart';
import 'authentication_overlay.dart';
import 'authentication_overlay_model.dart';
import 'child_constraints_changer.dart';
import 'constraints_model.dart';
import 'debug_text.dart';
import 'netstack_model.dart';
import 'soft_keyboard_container_impl.dart';
import 'user_picker_device_shell_model.dart';
import 'user_picker_device_shell_screen.dart';
import 'wlan_model.dart';

/// Set to true to have this BaseShell provide IME services.
const bool _kAdvertiseImeService = false;

/// Set to true to enable the performance overlay.
const bool _kShowPerformanceOverlay = false;

const double _kMousePointerElevation = 800.0;
const double _kIndicatorElevation = _kMousePointerElevation - 1.0;

void main() {
  setupLogger(name: 'userpicker_device_shell');
  GlobalKey screenManagerKey = new GlobalKey();
  ConstraintsModel constraintsModel = new ConstraintsModel();
  AuthenticationOverlayModel authenticationOverlayModel =
      new AuthenticationOverlayModel();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  NetstackProxy netstackProxy = new NetstackProxy();
  connectToService(
    applicationContext.environmentServices,
    netstackProxy.ctrl,
  );

  UserPickerDeviceShellModel userPickerDeviceShellModel =
      new UserPickerDeviceShellModel(
    onDeviceShellStopped: () {
      netstackProxy.ctrl.close();
    },
  );

  NetstackModel netstackModel = new NetstackModel(
    netstack: netstackProxy,
    tickerProvider: userPickerDeviceShellModel,
  );

  WlanProxy wlanProxy = new WlanProxy();
  connectToService(
    applicationContext.environmentServices,
    wlanProxy.ctrl,
  );

  WlanModel wlanModel = new WlanModel(
    wlan: wlanProxy,
  );

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
      builder: (BuildContext context) => new Align(
            alignment: FractionalOffset.topCenter,
            child: new DebugText(),
          ),
    ),
    new OverlayEntry(
      builder: (BuildContext context) => new Align(
            alignment: FractionalOffset.centerRight,
            child: new Container(
              margin: const EdgeInsets.all(8.0),
              child: new PhysicalModel(
                color: Colors.grey[900],
                elevation: _kIndicatorElevation,
                borderRadius: new BorderRadius.circular(8.0),
                child: new Container(
                  padding: const EdgeInsets.all(8.0),
                  child: new _NetstackInfo(),
                ),
              ),
            ),
          ),
    ),
    new OverlayEntry(
      builder: (BuildContext context) => new Align(
            alignment: FractionalOffset.centerLeft,
            child: new _WlanInfo(),
          ),
    ),
  ];

  DeviceShellWidget<UserPickerDeviceShellModel> deviceShellWidget =
      new DeviceShellWidget<UserPickerDeviceShellModel>(
    applicationContext: applicationContext,
    softKeyboardContainer: softKeyboardContainerImpl,
    deviceShellModel: userPickerDeviceShellModel,
    authenticationContext: new AuthenticationContextImpl(
      onStartOverlay: authenticationOverlayModel.onStartOverlay,
      onStopOverlay: authenticationOverlayModel.onStopOverlay,
    ),
    child: new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          (constraints.biggest == Size.zero)
              ? const Offstage()
              : new _ElevatedCheckedModeBanner(
                  child: new ScopedModel<NetstackModel>(
                    model: netstackModel,
                    child: new ScopedModel<WlanModel>(
                      model: wlanModel,
                      child: new Overlay(initialEntries: overlays),
                    ),
                  ),
                ),
    ),
  );

  runApp(deviceShellWidget);

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

const double _kOffset =
    40.0; // distance to bottom of banner, at a 45 degree angle inwards
const double _kHeight = 12.0; // height of banner
const double _kWidth = 200.0; // width of banner
const double _kSqrt2Over2 = 0.707;
const double _kJustUnderMaxElevation = 999.0; // Max visible elevation is 1000.0
const Color _kColor = const Color(0xA0B71C1C);
const TextStyle _kTextStyle = const TextStyle(
  color: const Color(0xFFFFFFFF),
  fontSize: _kHeight * 0.85,
  fontWeight: FontWeight.w900,
  height: 1.0,
);

class _ElevatedCheckedModeBanner extends StatelessWidget {
  /// Child to place under the banner.
  final Widget child;

  /// Constructor.
  const _ElevatedCheckedModeBanner({this.child});

  @override
  Widget build(BuildContext context) {
    bool offstage = true;
    assert(() {
      offstage = false;
      return true;
    });
    return offstage
        ? child
        : new Stack(
            children: <Widget>[
              new Align(
                alignment: FractionalOffset.topRight,
                child: new Transform(
                  transform: new Matrix4.translationValues(
                    -(_kOffset - _kHeight / 2.0) * _kSqrt2Over2 + _kWidth / 2.0,
                    (_kOffset - _kHeight / 2.0) * _kSqrt2Over2 - _kHeight / 2.0,
                    0.0,
                  ),
                  child: new Transform(
                    transform: new Matrix4.rotationZ(math.PI / 4.0),
                    alignment: FractionalOffset.center,
                    child: new IgnorePointer(
                      child: new PhysicalModel(
                        color: _kColor,
                        elevation: _kJustUnderMaxElevation,
                        child: new Container(
                          height: _kHeight,
                          width: _kWidth,
                          color: _kColor,
                          child: new Center(
                            child: const Text(
                              'SLOW MODE',
                              textAlign: TextAlign.center,
                              style: _kTextStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          );
  }
}

class _NetstackInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<NetstackModel>(
        builder:
            (BuildContext context, Widget child, NetstackModel netstackModel) =>
                new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: netstackModel.interfaces
                      .map(
                        (InterfaceInfo info) => new Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new Text(info.name),
                                new Container(width: 4.0),
                                new Container(
                                  width: 16.0,
                                  child: _wrapIcon(
                                    info.sendingRevealAnimation,
                                    info.sendingRepeatAnimation,
                                    Icons.arrow_upward,
                                    Colors.grey,
                                  ),
                                ),
                                new Container(width: 4.0),
                                new Container(
                                  width: 16.0,
                                  child: _wrapIcon(
                                    info.receivingRevealAnimation,
                                    info.receivingRepeatAnimation,
                                    Icons.arrow_downward,
                                    Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                      )
                      .toList(),
                ),
      );

  Widget _wrapIcon(
    Animation<double> reveal,
    Animation<double> repeat,
    IconData iconData,
    MaterialColor palette,
  ) =>
      new AnimatedBuilder(
        animation: new Listenable.merge(<Listenable>[reveal, repeat]),
        builder: (BuildContext context, Widget child) => new Icon(
              iconData,
              color: Color.lerp(
                  Colors.grey[800],
                  Color.lerp(
                    palette[100],
                    palette[300],
                    ((repeat.value - 0.5) / 0.5).abs(),
                  ),
                  reveal.value),
              size: 16.0,
            ),
      );
}

class _WlanInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<WlanModel>(
        builder: (
          BuildContext context,
          Widget child,
          WlanModel wlanModel,
        ) =>
            wlanModel.accessPoints.isEmpty
                ? const Offstage()
                : new Container(
                    margin: const EdgeInsets.all(8.0),
                    child: new PhysicalModel(
                      color: Colors.grey[900],
                      elevation: _kIndicatorElevation,
                      borderRadius: new BorderRadius.circular(8.0),
                      child: new Container(
                        padding: const EdgeInsets.all(8.0),
                        child: new Column(
                          mainAxisSize: MainAxisSize.min,
                          children: wlanModel.accessPoints
                              .map(
                                (AccessPoint accessPoint) => new Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        new Container(
                                          width: 150.0,
                                          child: new Text(
                                            accessPoint.name,
                                            overflow: TextOverflow.fade,
                                            maxLines: 1,
                                          ),
                                        ),
                                        new Container(width: 8.0),
                                        new Image.asset(
                                          accessPoint.url,
                                          height: 20.0,
                                          width: 20.0,
                                        ),
                                      ],
                                    ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
      );
}

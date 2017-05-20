// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.widgets/widgets.dart';

import 'authentication_overlay.dart';
import 'authentication_overlay_model.dart';
import 'authentication_context_impl.dart';
import 'child_constraints_changer.dart';
import 'constraints_model.dart';
import 'debug_text.dart';
import 'rounded_corner_decoration.dart';
import 'screen_manager.dart';
import 'soft_keyboard_container_impl.dart';
import 'user_picker_device_shell_model.dart';

const double _kInnerBezelRadius = 8.0;

void main() {
  GlobalKey screenManagerKey = new GlobalKey();
  ConstraintsModel constraintsModel = new ConstraintsModel();
  UserPickerDeviceShellModel model = new UserPickerDeviceShellModel();
  AuthenticationOverlayModel authenticationOverlayModel =
      new AuthenticationOverlayModel();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  SoftKeyboardContainerImpl softKeyboardContainerImpl =
      new SoftKeyboardContainerImpl(
    child: new ApplicationWidget(
      url: 'file:///system/apps/latin-ime',
      launcher: applicationContext.launcher,
    ),
  );

  DeviceShellWidget<UserPickerDeviceShellModel> deviceShellWidget =
      new DeviceShellWidget<UserPickerDeviceShellModel>(
    applicationContext: applicationContext,
    softKeyboardContainer: softKeyboardContainerImpl,
    deviceShellModel: model,
    authenticationContext: new AuthenticationContextImpl(
      onStartOverlay: authenticationOverlayModel.onStartOverlay,
      onStopOverlay: authenticationOverlayModel.onStopOverlay,
    ),
    child: new ChildConstraintsChanger(
      constraintsModel: constraintsModel,
      child: softKeyboardContainerImpl.wrap(
        child: new Container(
          foregroundDecoration: new RoundedCornerDecoration(
            radius: _kInnerBezelRadius,
            color: Colors.black,
          ),
          child: new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              new ScreenManager(
                key: screenManagerKey,
                onLogout: model.refreshUsers,
                onAddUser: model.showNewUserForm,
                onRemoveUser: model.removeUser,
                launcher: applicationContext.launcher,
              ),
              new ScopedModel<AuthenticationOverlayModel>(
                model: authenticationOverlayModel,
                child: new AuthenticationOverlay(),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  runApp(
    new CheckedModeBanner(
      child: new Overlay(
        initialEntries: <OverlayEntry>[
          new OverlayEntry(
            builder: (BuildContext context) => new MediaQuery(
                  data: const MediaQueryData(),
                  child: new FocusScope(
                    node: new FocusScopeNode(),
                    autofocus: true,
                    child: deviceShellWidget,
                  ),
                ),
          ),
          new OverlayEntry(
            builder: (_) => new Align(
                  alignment: FractionalOffset.topCenter,
                  child: new DebugText(),
                ),
          )
        ],
      ),
    ),
  );

  constraintsModel.load(rootBundle);
  deviceShellWidget.advertise();
  softKeyboardContainerImpl.advertise();
}

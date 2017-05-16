// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'authentication_overlay.dart';
import 'authentication_overlay_model.dart';
import 'authentication_context_impl.dart';
import 'child_constraints_changer.dart';
import 'constraints_model.dart';
import 'debug_text.dart';
import 'screen_manager.dart';
import 'user_picker_device_shell_model.dart';

void main() {
  GlobalKey screenManagerKey = new GlobalKey();
  ConstraintsModel constraintsModel = new ConstraintsModel();

  UserPickerDeviceShellModel model = new UserPickerDeviceShellModel();
  AuthenticationOverlayModel authenticationOverlayModel =
      new AuthenticationOverlayModel();
  AuthenticationContextImpl authenticationContext =
      new AuthenticationContextImpl(
    onStartOverlay: authenticationOverlayModel.onStartOverlay,
    onStopOverlay: authenticationOverlayModel.onStopOverlay,
  );

  DeviceShellWidget<UserPickerDeviceShellModel> deviceShellWidget =
      new DeviceShellWidget<UserPickerDeviceShellModel>(
    deviceShellModel: model,
    authenticationContext: authenticationContext,
    child: new ChildConstraintsChanger(
      constraintsModel: constraintsModel,
      child: new Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          new ScreenManager(
            key: screenManagerKey,
            onLogout: model.refreshUsers,
            onAddUser: model.showNewUserForm,
            onRemoveUser: model.removeUser,
          ),
          new ScopedModel<AuthenticationOverlayModel>(
            model: authenticationOverlayModel,
            child: new AuthenticationOverlay(),
          ),
        ],
      ),
    ),
  );

  runApp(
    new Overlay(
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
                alignment: FractionalOffset.bottomCenter,
                child: new DebugText(),
              ),
        )
      ],
    ),
  );

  constraintsModel.load(rootBundle);
  deviceShellWidget.advertise();
}

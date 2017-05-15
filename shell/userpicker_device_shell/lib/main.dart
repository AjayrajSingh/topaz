// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/application_launcher.fidl.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.mozart.services.views/view_provider.fidl.dart';
import 'package:application.services/application_controller.fidl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/modular.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';

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

final ApplicationControllerProxy _imeApplicationController =
    new ApplicationControllerProxy();

/// Creates a [ViewProviderProxy] from a [ServiceProviderProxy], closing it in
/// the process.
ViewProviderProxy _consumeServiceProvider(
  ServiceProviderProxy serviceProvider,
) {
  ViewProviderProxy viewProvider = new ViewProviderProxy();
  connectToService(serviceProvider, viewProvider.ctrl);
  serviceProvider.ctrl.close();
  return viewProvider;
}

/// Creates a handle to a [ViewOwner] from a [ViewProviderProxy], closing it in
/// the process.
InterfaceHandle<ViewOwner> _consumeViewProvider(
  ViewProviderProxy viewProvider,
) {
  InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
  viewProvider.createView(viewOwner.passRequest(), null);
  viewProvider.ctrl.close();
  return viewOwner.passHandle();
}

void main() {
  GlobalKey screenManagerKey = new GlobalKey();
  ConstraintsModel constraintsModel = new ConstraintsModel();
  UserPickerDeviceShellModel model = new UserPickerDeviceShellModel();
  AuthenticationOverlayModel authenticationOverlayModel =
      new AuthenticationOverlayModel();

  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  ServiceProviderProxy incomingServices = new ServiceProviderProxy();
  applicationContext.launcher.createApplication(
    new ApplicationLaunchInfo()
      ..url = 'file:///system/apps/latin-ime'
      ..services = incomingServices.ctrl.request(),
    _imeApplicationController.ctrl.request(),
  );

  SoftKeyboardContainerImpl softKeyboardContainerImpl =
      new SoftKeyboardContainerImpl(
    softKeyboardView: _consumeViewProvider(
      _consumeServiceProvider(incomingServices),
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

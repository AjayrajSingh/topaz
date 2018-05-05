// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/application.dart';
import 'package:lib.widgets/model.dart';
import 'package:timezone/timezone_picker.dart';

import 'netstack_model.dart';
import 'user_setup_model.dart';

/// Callback to cancel the authentication flow
typedef void CancelAuthentication();

/// Move to a common place?
const double _kUserAvatarSizeLarge = 112.0;
const double _kButtonWidthLarge = 256.0;
final BorderRadius _kButtonBorderRadiusLarge =
    new BorderRadius.circular(_kUserAvatarSizeLarge / 2.0);

Widget _buildUserActionButton({
  Widget child,
  VoidCallback onTap,
  bool isSmall,
  double width,
  bool isDisabled: false,
}) {
  return new GestureDetector(
    onTap: () => onTap?.call(),
    child: new Container(
      height: _kUserAvatarSizeLarge,
      width: width ?? _kButtonWidthLarge,
      alignment: FractionalOffset.center,
      margin: const EdgeInsets.only(left: 16.0),
      decoration: new BoxDecoration(
        borderRadius: _kButtonBorderRadiusLarge,
        border: new Border.all(
          color: Colors.white,
          width: 1.0,
        ),
      ),
      child: child,
    ),
  );
}

/// Widget that handles the steps required to set up a new user.
class UserSetup extends StatelessWidget {
  static const TextStyle _textStyle = const TextStyle(
      fontSize: 24.0, color: Colors.white, fontWeight: FontWeight.w200);

  static const TextStyle _whiteText = const TextStyle(
      fontSize: 14.0, color: Colors.white, fontWeight: FontWeight.w200);

  static const Map<SetupStage, String> _stageTitles =
      const <SetupStage, String>{
    SetupStage.userAuth: 'Log in to your account',
    SetupStage.wifi: 'Connect to the internet',
  };

  /// Builds a new UserSetup widget that orchestrates the steps required
  const UserSetup();

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<UserSetupModel>(builder: (
        BuildContext context,
        Widget child,
        UserSetupModel model,
      ) {
        if (model.currentStage == SetupStage.notStarted ||
            model.currentStage == SetupStage.complete)
          return new Offstage(offstage: true);

        return new Material(
            color: Colors.white,
            child: model.currentStage == SetupStage.welcome
                ? _buildWelcomeScreen(context, child, model)
                : new Column(children: <Widget>[
                    _buildAppBar(model),
                    new Expanded(
                        child: _getWidgetBuilder(model.currentStage)
                            .call(context, child, model)),
                    _controlBar(model),
                  ]));
      });

  ScopedModelDescendantBuilder<UserSetupModel> _getWidgetBuilder(
      SetupStage stage) {
    switch (stage) {
      case SetupStage.userAuth:
        return _buildUserAuth;
      case SetupStage.wifi:
        return _buildWifi;
      default:
        return _placeholderStage;
    }
  }

  static Widget _buildAppBar(UserSetupModel model) => new AppBar(
        backgroundColor: Colors.blue,
        leading: new IconButton(
            color: Colors.white,
            onPressed: model.previousStep,
            icon: new Icon(Icons.arrow_back)),
        title: new Text(
          _stageTitles[model.currentStage] ?? 'Placeholder',
          style: _textStyle,
        ),
        actions: <Widget>[
          new Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new FlatButton(
                  color: Colors.blue,
                  child: new Text('Finish Later', style: _whiteText),
                  onPressed: model.loginAsGuest,
                )
              ])
        ],
      );

  static Widget _buildWifi(
          BuildContext context, Widget child, UserSetupModel model) =>
      new ApplicationWidget(
          url: 'wifi_settings', launcher: model.applicationContext.launcher);

  static Widget _placeholderStage(
          BuildContext context, Widget child, UserSetupModel model) =>
      _buildUserActionButton(
          isDisabled: false,
          child: new Text(
            'Stage: ${model.currentStage}',
            style: _textStyle,
          ),
          onTap: () {
            model.nextStep();
          });

  static Widget _buildUserAuth(
          BuildContext context, Widget child, UserSetupModel model) =>
      new AnimatedBuilder(
        animation: model.authModel.animation,
        builder: (BuildContext context, Widget child) => new Offstage(
              offstage: model.authModel.animation.isDismissed,
              child: new Opacity(
                opacity: model.authModel.animation.value,
                child: child,
              ),
            ),
        child: new ChildView(connection: model.authModel.childViewConnection),
      );

  static Widget _buildWelcomeScreen(
          BuildContext context, Widget child, UserSetupModel model) =>
      new Column(children: <Widget>[
        new Padding(
          padding: new EdgeInsets.only(top: 16.0),
        ),
        new Text('Welcome',
            style: const TextStyle(
                fontSize: 36.0,
                color: Colors.black,
                fontWeight: FontWeight.w200)),
        new Expanded(
            child: new TimezonePicker(
                onTap: (String newTimeZone) {
                  model.currentTimezone = newTimeZone;
                },
                currentTimezoneId: model.currentTimezone)),
        new IconButton(
          onPressed: model.nextStep,
          icon: new Icon(Icons.arrow_forward),
        )
      ]);

  static Widget _controlBar(UserSetupModel model) {
    return new Container(
        padding: const EdgeInsets.all(8.0),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new ScopedModelDescendant<NetstackModel>(
                builder: (BuildContext context, Widget child,
                        NetstackModel netModel) =>
                    model.currentStage != SetupStage.userAuth
                        ? new IconButton(
                            onPressed: model.nextStep,
                            icon: new Icon(Icons.arrow_forward),
                          )
                        : null)
          ].where((Widget widget) => widget != null).toList(),
        ));
  }
}

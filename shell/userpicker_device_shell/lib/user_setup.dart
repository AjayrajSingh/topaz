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
  static const TextStyle _textStyle =
      const TextStyle(fontSize: 30.0, color: Colors.white);

  static const TextStyle _blackText =
      const TextStyle(fontSize: 14.0, color: Colors.white);

  static const Map<SetupStage, String> _stageTitles =
      const <SetupStage, String>{
    SetupStage.timeZone: 'Select your time zone',
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
            child: new Column(children: <Widget>[
              new AppBar(
                  title: new Text(
                      _stageTitles[model.currentStage] ?? 'Placeholder')),
              new Expanded(
                  child: _getWidgetBuilder(model.currentStage)
                      .call(context, child, model)),
              _controlBar(model),
            ]));
      });

  ScopedModelDescendantBuilder<UserSetupModel> _getWidgetBuilder(
      SetupStage stage) {
    switch (stage) {
      case SetupStage.timeZone:
        return _buildTimeZone;
      case SetupStage.userAuth:
        return _buildUserAuth;
      case SetupStage.wifi:
        return _buildWifi;
      default:
        return _placeholderStage;
    }
  }

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

  static Widget _buildTimeZone(
          BuildContext context, Widget child, UserSetupModel model) =>
      new TimezonePicker(
          onTap: (String newTimeZone) {
            model.currentTimezone = newTimeZone;
          },
          currentTimezoneId: model.currentTimezone);

  static Widget _controlBar(UserSetupModel model) {
    return new Container(
        padding: const EdgeInsets.all(8.0),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _textButton(
                text: 'Cancel',
                onPressed: () {
                  model.reset();
                  model.cancelAuthenticationFlow();
                }),
            new ScopedModelDescendant<NetstackModel>(
                builder: (BuildContext context, Widget child,
                        NetstackModel netModel) =>
                    _textButton(
                        text: 'Next',
                        visible: model.currentStage != SetupStage.userAuth,
                        disabled: model.currentStage == SetupStage.wifi &&
                            netModel.hasIp,
                        onPressed: () => model.nextStep())),
            _textButton(text: 'Guest', onPressed: () => model.loginAsGuest()),
          ].where((Widget widget) => widget != null).toList(),
        ));
  }

  static Widget _textButton(
          {@required String text,
          bool disabled = false,
          bool visible = true,
          VoidCallback onPressed}) =>
      visible
          ? new RaisedButton(
              color: Colors.blueAccent,
              shape: new RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(28.0)),
              onPressed: disabled ? null : onPressed,
              child: new Text(text, style: _blackText))
          : null;
}

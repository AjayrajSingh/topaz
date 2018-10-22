// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.ui.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'authentication_overlay_model.dart';

/// Signature for callback used to indicate that the user cancelled the authorization
/// flow.
typedef AuthenticationCancelCallback = void Function();

/// Displays the authentication window.
class AuthenticationOverlay extends StatelessWidget {
  /// Constructs an authentication overlay that calls the provided callback if the
  /// user cancels the login flow.
  const AuthenticationOverlay({AuthenticationCancelCallback onCancel})
      : _onCancel = onCancel;

  /// The callback that is triggered when the user taps outside of the child view,
  /// cancelling the authorization flow.
  final AuthenticationCancelCallback _onCancel;

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<AuthenticationOverlayModel>(
        builder: (
          BuildContext context,
          Widget child,
          AuthenticationOverlayModel model,
        ) =>
            new AnimatedBuilder(
              animation: model.animation,
              builder: (BuildContext context, Widget child) => new Offstage(
                    offstage: model.animation.isDismissed,
                    child: new Opacity(
                      opacity: model.animation.value,
                      child: child,
                    ),
                  ),
              child: new Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  new GestureDetector(
                    onTap: _onCancel,
                  ),
                  new FractionallySizedBox(
                    widthFactor: 0.75,
                    heightFactor: 0.75,
                    child: new ChildView(
                      connection: model.childViewConnection,
                    ),
                  ),
                ],
              ),
            ),
      );
}

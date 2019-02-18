// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:zircon/zircon.dart';

/// Manages the connection and animation of the authentication window.
class AuthenticationOverlayModel extends Model implements TickerProvider {
  ChildViewConnection _childViewConnection;
  AnimationController _transitionAnimation;
  CurvedAnimation _curvedTransitionAnimation;

  /// Constructor.
  AuthenticationOverlayModel() {
    _transitionAnimation = new AnimationController(
      value: 0.0,
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _curvedTransitionAnimation = new CurvedAnimation(
      parent: _transitionAnimation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  /// If not null, returns the handle of the current requested overlay.
  ChildViewConnection get childViewConnection => _childViewConnection;

  /// The animation controlling the fading in and out of the authentication
  /// overlay.
  CurvedAnimation get animation => _curvedTransitionAnimation;

  /// Starts showing an overlay over all other content.
  void onStartOverlay(EventPair overlayViewHolderToken) {
    _childViewConnection = new ChildViewConnection.fromViewHolderToken(
      overlayViewHolderToken,
      onAvailable: (ChildViewConnection connection) {
        log.fine(
          'AuthenticationOverlayModel: Child view connection available!',
        );
        _transitionAnimation.forward();
        connection.requestFocus();
      },
      onUnavailable: (ChildViewConnection connection) {
        log.fine(
          'AuthenticationOverlayModel: Child view connection unavailable!',
        );
        _transitionAnimation.reverse();
        // TODO(apwilson): Should not need to remove the child view
        // connection but it causes a scenic deadlock in the compositor if you
        // don't.
        _childViewConnection = null;
      },
    );
    notifyListeners();
  }

  /// Stops showing a previously started overlay.
  void onStopOverlay() {
    _transitionAnimation.reverse();
    // TODO(apwilson): Should not need to remove the child view
    // connection but it causes a scenic deadlock in the compositor if you
    // don't.
    _childViewConnection = null;
    notifyListeners();
  }

  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);
}

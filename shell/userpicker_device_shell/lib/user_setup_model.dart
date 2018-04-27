// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:fuchsia.fidl.time_zone/time_zone.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/model.dart';

import 'authentication_overlay_model.dart';
import 'netstack_model.dart';

/// Enum of the possible stages that are displayed during user setup.
///
/// The enum order is not equal to the order of steps.
enum SetupStage {
  /// When the setup has not yet started.
  notStarted,

  /// When logging in to a new user.
  userAuth,

  /// When selecting the time zone.
  timeZone,

  /// When connecting to wireless internet.
  wifi,

  /// When the setup is complete.
  complete,
}

const List<SetupStage> _stages = const <SetupStage>[
  SetupStage.notStarted,
  SetupStage.timeZone,
  SetupStage.wifi,
  SetupStage.userAuth,
  SetupStage.complete
];

/// Model that contains all the state needed to set up a new user
class UserSetupModel extends Model {
  final AuthenticationOverlayModel _authModel;
  final NetstackModel _netstackModel;

  /// ApplicationContext to allow setup to launch apps
  final ApplicationContext applicationContext;

  /// Callback to cancel adding a new user.
  final VoidCallback cancelAuthenticationFlow;

  final TimezoneProxy _timeZoneProxy;

  /// Callback to add a new user.
  VoidCallback addNewUser;

  VoidCallback _loginAsGuest;

  int _currentIndex;

  /// Create a new [UserSetupModel]
  UserSetupModel(this.applicationContext, this._netstackModel,
      this.cancelAuthenticationFlow)
      : _currentIndex = _stages.indexOf(SetupStage.notStarted),
        _authModel = new AuthenticationOverlayModel(),
        _timeZoneProxy = new TimezoneProxy() {
    connectToService(
        applicationContext.environmentServices, _timeZoneProxy.ctrl);

    _timeZoneProxy.getTimezoneId((String tz) {
      _currentTimezone = tz;
      notifyListeners();
    });
  }

  /// The overlay model for the authentication flow
  AuthenticationOverlayModel get authModel => _authModel;

  /// The current stage that the setup flow is in.
  SetupStage get currentStage => _stages[_currentIndex];

  /// Cancels the setup flow, moving back to the beginning.
  void reset() {
    _currentIndex = _stages.indexOf(SetupStage.notStarted);
    notifyListeners();
  }

  /// Begin setup phase
  void start({
    @required VoidCallback addNewUser,
    @required VoidCallback loginAsGuest,
  }) {
    // This should be refactored into the model
    this.addNewUser = addNewUser;
    _loginAsGuest = loginAsGuest;

    _currentIndex = _stages.indexOf(SetupStage.notStarted);
    nextStep();
  }

  /// Moves to the next stage in the setup flow.
  void nextStep() {
    do {
      assert(currentStage != SetupStage.complete);
      _currentIndex++;
    } while (_shouldSkipStage);

    // This will be refactored into the model, and then called when
    // building the userAuth widget.
    if (currentStage == SetupStage.userAuth) {
      addNewUser();
    }

    notifyListeners();
  }

  /// Moves to the previous step in the setup flow
  void previousStep() {
    assert(currentStage != SetupStage.notStarted);

    _currentIndex--;
    notifyListeners();
  }

  /// Function called with the authentication flow is completed.
  void endAuthFlow() {
    authModel.onStopOverlay();
    nextStep();
  }

  String _currentTimezone;

  /// Returns the current timezone.
  String get currentTimezone => _currentTimezone;

  /// Sets the current timezone
  set currentTimezone(String newTimezone) {
    _timeZoneProxy.setTimezone(newTimezone, (bool succeeded) {
      assert(succeeded);
      _currentTimezone = newTimezone;
      notifyListeners();
    });
  }

  /// If the stage isn't needed due to current conditions.
  bool get _shouldSkipStage =>
      currentStage == SetupStage.wifi && _netstackModel.hasIp;

  /// Ends the setup flow and immediately logs in as guest
  void loginAsGuest() {
    _currentIndex = _stages.indexOf(SetupStage.complete);
    notifyListeners();
    _loginAsGuest();
  }
}

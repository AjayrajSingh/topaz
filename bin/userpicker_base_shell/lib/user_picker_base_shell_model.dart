// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl_fuchsia_cobalt/fidl.dart' as cobalt;
import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.base_shell/base_model.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, ScopedModelDescendant, ModelFinder;

/// Function signature for GetPresentationMode callback
typedef GetPresentationModeCallback = void Function(PresentationMode mode);

const Duration _kShowLoadingSpinnerDelay = const Duration(milliseconds: 500);

/// Model that provides common state
class UserPickerBaseShellModel extends CommonBaseShellModel
    with TickerProviderModelMixin
    implements
        Presentation,
        ServiceProvider,
        KeyboardCaptureListenerHack,
        PointerCaptureListenerHack,
        PresentationModeListener {
  /// Called when the base shell stops.
  final VoidCallback onBaseShellStopped;

  /// Called when wifi is tapped.
  final VoidCallback onWifiTapped;

  /// Called when a user is logging in.
  final VoidCallback onLogin;

  bool _showingUserActions = false;
  bool _addingUser = false;
  bool _loadingChildView = false;
  final Set<Account> _draggedUsers = new Set<Account>();

  /// Constructor
  UserPickerBaseShellModel({
    this.onBaseShellStopped,
    this.onWifiTapped,
    this.onLogin,
    cobalt.Logger logger,
  }) : super(logger);

  @override
  void onStop() {
    onBaseShellStopped?.call();
    super.dispose();
    super.onStop();
  }

  /// Refreshes the list of users.
  @override
  Future<void> refreshUsers() async {
    _updateShowLoadingSpinner();
    notifyListeners();
    await super.refreshUsers();
    _updateShowLoadingSpinner();
    notifyListeners();
  }

  /// Call when wifi is tapped.
  void wifiTapped() {
    onWifiTapped?.call();
  }

  /// Call when reset is tapped.
  void resetTapped() {
    File dm = new File('/dev/misc/dmctl');
    print('dmctl exists? ${dm.existsSync()}');
    if (dm.existsSync()) {
      dm.writeAsStringSync('reboot', flush: true);
    }
  }

  /// Create a new user and login with that user
  @override
  Future createAndLoginUser() async {
    _addingUser = true;
    _updateShowLoadingSpinner();

    await super.createAndLoginUser();

    _addingUser = false;
    _updateShowLoadingSpinner();
    notifyListeners();
  }

  /// Login with given user
  @override
  Future<void> login(String accountId) async {
    _loadingChildView = true;
    _updateShowLoadingSpinner();
    notifyListeners();

    await super.login(accountId);

    _loadingChildView = false;
    _updateShowLoadingSpinner();
    notifyListeners();
  }

  /// Show advanced user actions such as:
  /// * Guest login
  /// * Create new account
  void showUserActions() {
    _showingUserActions = true;
    notifyListeners();
  }

  /// Hide advanced user actions such as:
  void hideUserActions() {
    _showingUserActions = false;
    notifyListeners();
  }

  /// Add a user to the list of dragged users
  void addDraggedUser(Account account) {
    _draggedUsers.add(account);
    notifyListeners();
  }

  /// Remove a user from the list of dragged users
  void removeDraggedUser(Account account) {
    _draggedUsers.remove(account);
    notifyListeners();
  }

  /// Show the loading spinner if true
  bool get showingLoadingSpinner => _showingLoadingSpinner;

  /// Show the system clock if true
  bool get showingClock =>
      !showingLoadingSpinner &&
      _draggedUsers.isEmpty &&
      childViewConnection == null;

  /// If true, show advanced user actions
  bool get showingUserActions => _showingUserActions;

  /// If true, show the remove user target
  bool get showingRemoveUserTarget => _draggedUsers.isNotEmpty;

  /// Returns true the add user dialog is showing
  bool get addingUser => _addingUser;

  /// Returns true if we are "loading" the child view
  bool get loadingChildView => _loadingChildView;

  bool _showingLoadingSpinner = true;
  Timer _showLoadingSpinnerTimer;

  void _updateShowLoadingSpinner() {
    if (accounts == null || _addingUser || _loadingChildView) {
      if (_showingLoadingSpinner == null) {
        _showLoadingSpinnerTimer = new Timer(
          _kShowLoadingSpinnerDelay,
          () {
            _showingLoadingSpinner = true;
            _showLoadingSpinnerTimer = null;
            notifyListeners();
          },
        );
      }
    } else {
      _showLoadingSpinnerTimer?.cancel();
      _showLoadingSpinnerTimer = null;
      _showingLoadingSpinner = false;
      notifyListeners();
    }
  }
}

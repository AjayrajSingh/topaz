// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:apps.modular.services.auth.account/account.fidl.dart';
import 'package:apps.modular.services.config/config.fidl.dart';
import 'package:apps.modular.services.device/device_shell.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, ScopedModelDescendant, ModelFinder;

import 'user_shell_chooser.dart';
import 'user_watcher_impl.dart';

/// Contains all the relevant data for displaying the list of users and for
/// logging in and creating new users.
class UserPickerDeviceShellModel extends DeviceShellModel
    implements TickerProvider {
  bool _showingUserActions = false;
  bool _addingUser = false;
  bool _showingKernelPanic = false;
  UserControllerProxy _userControllerProxy;
  UserWatcherImpl _userWatcherImpl;
  List<Account> _accounts;
  final ScrollController _userPickerScrollController = new ScrollController();
  final UserShellChooser _userShellChooser = new UserShellChooser();
  ChildViewConnection _childViewConnection;
  final Set<Account> _draggedUsers = new Set<Account>();

  /// Constructor
  UserPickerDeviceShellModel() : super() {
    // Check for last kernel panic
    File lastPanic = new File('/boot/log/last-panic.txt');
    lastPanic.exists().then((bool exists) {
      if (exists) {
        _showingKernelPanic = true;
        notifyListeners();
      }
    });
  }

  /// The list of previously logged in accounts.
  List<Account> get accounts => _accounts;

  /// Scroll Controller for the user picker
  ScrollController get userPickerScrollController =>
      _userPickerScrollController;

  @override
  void onReady(
    UserProvider userProvider,
    DeviceShellContext deviceShellContext,
  ) {
    super.onReady(userProvider, deviceShellContext);
    _loadUsers();
    _userPickerScrollController.addListener(_scrollListener);
  }

  // Hide user actions on overscroll
  void _scrollListener() {
    if (_userPickerScrollController.offset >
        _userPickerScrollController.position.maxScrollExtent + 40.0) {
      hideUserActions();
    }
  }

  /// Refreshes the list of users.
  void refreshUsers() {
    _loadUsers();
  }

  void _loadUsers() {
    userProvider.previousUsers((List<Account> accounts) {
      _accounts = new List<Account>.from(accounts);
      notifyListeners();
    });
  }

  /// Permanently removes the user.
  void removeUser(Account account) {
    userProvider.removeUser(account.id, (String errorCode) {
      if (errorCode != null && errorCode != "") {
        log.severe('Error in revoking credentials ${account.id}: $errorCode');
        refreshUsers();
        return;
      }

      _accounts.remove(account);
      notifyListeners();
      _loadUsers();
    });

    _draggedUsers.clear();
    notifyListeners();
  }

  /// Create a new user and login with that user
  void createAndLoginUser() {
    _addingUser = true;
    notifyListeners();

    userProvider.addUser(
      IdentityProvider.google,
      (Account account, String errorCode) {
        if (errorCode == null) {
          login(account.id);
        } else {
          log.warning('ERROR adding user!  $errorCode');
        }
        _addingUser = false;
        notifyListeners();
      },
    );
  }

  /// Login with given user
  void login(String accountId) {
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = new UserControllerProxy();
    _userWatcherImpl?.close();
    _userWatcherImpl = new UserWatcherImpl(onUserLogout: () {
      log.info('UserPickerDeviceShell: User logged out!');
      onLogout();
    });

    final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    final UserLoginParams params = new UserLoginParams()
      ..accountId = accountId
      ..viewOwner = viewOwner.passRequest()
      ..userController = _userControllerProxy.ctrl.request()
      ..userShellConfig = new AppConfig.init(_userShellChooser.appUrl, null);
    userProvider.login(params);
    _userControllerProxy.watch(_userWatcherImpl.getHandle());
    _childViewConnection = new ChildViewConnection(
      viewOwner.passHandle(),
      onAvailable: (ChildViewConnection connection) {
        log.info('UserPickerDeviceShell: Child view connection available!');
      },
      onUnavailable: (ChildViewConnection connection) {
        log.info('UserPickerDeviceShell: Child view connection unavailable!');
        onLogout();
      },
    );
    notifyListeners();
  }

  /// Called when the the user shell logs out.
  void onLogout() {
    refreshUsers();
    _childViewConnection = null;
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

  /// Hide the kernel panic screen
  void hideKernelPanic() {
    _showingKernelPanic = false;
    notifyListeners();
  }

  /// Show the loading spinner if true
  bool get showingLoadingSpinner => _accounts == null || _addingUser;

  /// Show the system clock if true
  bool get showingClock => !showingLoadingSpinner && _draggedUsers.isEmpty;

  /// If true, show advanced user actions
  bool get showingUserActions => _showingUserActions;

  /// If true, show the remove user target
  bool get showingRemoveUserTarget => _draggedUsers.isNotEmpty;

  /// If true, show kernel panic screen
  bool get showingKernelPanic => _showingKernelPanic;

  /// Returns true the add user dialog is showing
  bool get addingUser => _addingUser;

  /// Returns the authenticated child view connection
  ChildViewConnection get childViewConnection => _childViewConnection;

  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);
}

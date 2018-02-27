// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.auth.fidl.account/account.fidl.dart';
import 'package:lib.config.fidl/config.fidl.dart';
import 'package:lib.device.fidl/device_shell.fidl.dart';
import 'package:lib.device.fidl/user_provider.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.ui.presentation.fidl/display_usage.fidl.dart';
import 'package:lib.ui.presentation.fidl/presentation.fidl.dart';
import 'package:lib.ui.scenic.fidl/renderer.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:zircon/zircon.dart' show Channel;

import 'user_shell_chooser.dart';
import 'user_watcher_impl.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, ScopedModelDescendant, ModelFinder;

/// Contains all the relevant data for displaying the list of users and for
/// logging in and creating new users.
class UserPickerDeviceShellModel extends DeviceShellModel
    implements Presentation, ServiceProvider, TickerProvider {
  /// Called when the device shell stops.
  final VoidCallback onDeviceShellStopped;

  /// Called when wifi is tapped.
  final VoidCallback onWifiTapped;

  /// Called when a user is logging in.
  final VoidCallback onLogin;

  bool _showingUserActions = false;
  bool _addingUser = false;
  bool _loadingChildView = false;
  bool _showingKernelPanic = false;
  UserControllerProxy _userControllerProxy;
  UserWatcherImpl _userWatcherImpl;
  List<Account> _accounts;
  final ScrollController _userPickerScrollController = new ScrollController();
  final UserShellChooser _userShellChooser = new UserShellChooser();
  ChildViewConnection _childViewConnection;
  final Set<Account> _draggedUsers = new Set<Account>();
  final Set<Ticker> _tickers = new Set<Ticker>();

  // Because this device shell only supports a single user logged in at a time,
  // we don't need to maintain separate ServiceProvider and Presentation
  // bindings for each logged-in user.
  final PresentationBinding _presentationBinding = new PresentationBinding();
  final ServiceProviderBinding _serviceProviderBinding =
      new ServiceProviderBinding();

  /// Constructor
  UserPickerDeviceShellModel({
    this.onDeviceShellStopped,
    this.onWifiTapped,
    this.onLogin,
  })
      : super() {
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
    Presentation presentation,
  ) {
    super.onReady(userProvider, deviceShellContext, presentation);
    _loadUsers();
    _userPickerScrollController.addListener(_scrollListener);
  }

  @override
  void onStop() {
    _userControllerProxy?.ctrl?.close();
    _userWatcherImpl?.close();
    onDeviceShellStopped?.call();
    for (Ticker ticker in _tickers) {
      ticker.dispose();
    }
    super.onStop();
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

  /// Call when wifi is tapped.
  void wifiTapped() {
    onWifiTapped?.call();
  }

  /// Permanently removes the user.
  void removeUser(Account account) {
    userProvider.removeUser(account.id, (String errorCode) {
      if (errorCode != null && errorCode != '') {
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
    if (_serviceProviderBinding.isBound) {
      log.warning(
        'Ignoring unsupported attempt to log in'
            ' while already logged in!',
      );
      return;
    }
    onLogin?.call();
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = new UserControllerProxy();
    _userWatcherImpl?.close();
    _userWatcherImpl = new UserWatcherImpl(onUserLogout: () {
      log.info('UserPickerDeviceShell: User logged out!');
      onLogout();
    });

    final InterfacePair<ServiceProvider> serviceProvider =
        new InterfacePair<ServiceProvider>();
    _serviceProviderBinding.bind(this, serviceProvider.passRequest());

    final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    final UserLoginParams params = new UserLoginParams(
        accountId: accountId,
        viewOwner: viewOwner.passRequest(),
        services: serviceProvider.passHandle(),
        userController: _userControllerProxy.ctrl.request(),
        userShellConfig:
            new AppConfig(url: _userShellChooser.appUrl(accountId)));
    userProvider.login(params);

    _userControllerProxy.watch(_userWatcherImpl.getHandle());
    _loadingChildView = true;
    _childViewConnection = new ChildViewConnection(
      viewOwner.passHandle(),
      onAvailable: (ChildViewConnection connection) {
        log.info('UserPickerDeviceShell: Child view connection available!');
        _loadingChildView = false;
        connection.requestFocus();
        notifyListeners();
      },
      onUnavailable: (ChildViewConnection connection) {
        log.info('UserPickerDeviceShell: Child view connection unavailable!');
        _loadingChildView = false;
        onLogout();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  /// Called when the the user shell logs out.
  void onLogout() {
    refreshUsers();
    _childViewConnection = null;
    _presentationBinding.close();
    _serviceProviderBinding.close();
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
  bool get showingLoadingSpinner =>
      _accounts == null || _addingUser || _loadingChildView;

  /// Show the system clock if true
  bool get showingClock =>
      !showingLoadingSpinner &&
      _draggedUsers.isEmpty &&
      _childViewConnection == null;

  /// If true, show advanced user actions
  bool get showingUserActions => _showingUserActions;

  /// If true, show the remove user target
  bool get showingRemoveUserTarget => _draggedUsers.isNotEmpty;

  /// If true, show kernel panic screen
  bool get showingKernelPanic => _showingKernelPanic;

  /// Returns true the add user dialog is showing
  bool get addingUser => _addingUser;

  /// Returns true if we are "loading" the child view
  bool get loadingChildView => _loadingChildView;

  /// Returns the authenticated child view connection
  ChildViewConnection get childViewConnection => _childViewConnection;

  @override
  Ticker createTicker(TickerCallback onTick) {
    Ticker ticker = new Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }

  // |Presentation|.
  // Delegate to the Presentation received by DeviceShell.Initialize().
  // TODO: revert to default state when client logs out.
  @override
  // ignore: avoid_positional_boolean_parameters
  void enableClipping(bool enabled) {
    presentation.enableClipping(enabled);
  }

  // |Presentation|.
  // Delegate to the Presentation received by DeviceShell.Initialize().
  // TODO: revert to default state when client logs out.
  @override
  void useOrthographicView() {
    presentation.useOrthographicView();
  }

  // |Presentation|.
  // Delegate to the Presentation received by DeviceShell.Initialize().
  // TODO: revert to default state when client logs out.
  @override
  void usePerspectiveView() {
    presentation.usePerspectiveView();
  }

  // |Presentation|.
  // Delegate to the Presentation received by DeviceShell.Initialize().
  // TODO: revert to default state when client logs out.
  @override
  void setRendererParams(List<RendererParam> params) {
    presentation.setRendererParams(params);
  }

  @override
  void setDisplayUsage(DisplayUsage usage) {
    presentation.setDisplayUsage(usage);
  }

  // |ServiceProvider|.
  @override
  void connectToService(String serviceName, Channel channel) {
    if (serviceName == 'mozart.Presentation') {
      if (_presentationBinding.isBound) {
        log.warning(
            'UserPickerDeviceShell: Presentation service is already bound !');
      } else {
        _presentationBinding.bind(
            this, new InterfaceRequest<Presentation>(channel));
      }
    } else {
      log.warning(
          'UserPickerDeviceShell: received request for unknown service: $serviceName !');
      channel.close();
    }
  }
}

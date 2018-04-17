// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:fuchsia.fidl.cobalt/cobalt.dart' as cobalt;
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fuchsia.fidl.modular_auth/modular_auth.dart';
import 'package:fuchsia.fidl.input/input.dart'
    show KeyboardEvent, KeyboardEventPhase;
import 'package:fuchsia.fidl.presentation/presentation.dart';
import 'package:fuchsia.fidl.gfx/gfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:zircon/zircon.dart' show Channel;

import 'user_shell_chooser.dart';
import 'user_watcher_impl.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, ScopedModelDescendant, ModelFinder;

/// Function signature for GetPresentationMode callback
typedef void GetPresentationModeCallback(PresentationMode mode);

const Duration _kCobaltTimerTimeout = const Duration(seconds: 20);
const int _kNoOpEncodingId = 1;
const int _kUserShellLoginTimeMetricId = 14;
const int _kKeyModifierLeftCtrl = 8;
const int _kKeyModifierRightAlt = 64;
const int _kKeyCodeSpacebar = 32;
const int _kKeyCodeL = 108;
const int _kKeyCodeS = 115;

/// Contains all the relevant data for displaying the list of users and for
/// logging in and creating new users.
class UserPickerDeviceShellModel extends DeviceShellModel
    implements
        Presentation,
        ServiceProvider,
        TickerProvider,
        KeyboardCaptureListener,
        PresentationModeListener {
  /// Called when the device shell stops.
  final VoidCallback onDeviceShellStopped;

  /// Called when wifi is tapped.
  final VoidCallback onWifiTapped;

  /// Called when a user is logging in.
  final VoidCallback onLogin;

  /// Encodes metrics into cobalt.
  final cobalt.CobaltEncoder encoder;

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
  final KeyboardCaptureListenerBinding _keyboardCaptureListenerBindingSpaceBar =
      new KeyboardCaptureListenerBinding();
  final KeyboardCaptureListenerBinding _keyboardCaptureListenerBindingS =
      new KeyboardCaptureListenerBinding();
  final KeyboardCaptureListenerBinding _keyboardCaptureListenerBindingL =
      new KeyboardCaptureListenerBinding();
  final PresentationModeListenerBinding _presentationModeListenerBinding =
      new PresentationModeListenerBinding();
  String _currentAccountId = '';
  ShadowTechnique _currentShadowTechnique = ShadowTechnique.unshadowed;
  bool _currentClippingEnabled = true;

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
    this.encoder,
  }) : super() {
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
    enableClipping(_currentClippingEnabled);
    presentation
      ..captureKeyboardEvent(
        new KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeSpacebar,
          modifiers: _kKeyModifierLeftCtrl,
          phase: KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingSpaceBar.wrap(this),
      )
      ..captureKeyboardEvent(
        new KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeS,
          modifiers: _kKeyModifierLeftCtrl,
          phase: KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingS.wrap(this),
      )
      ..captureKeyboardEvent(
        new KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeL,
          modifiers: _kKeyModifierRightAlt,
          phase: KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingL.wrap(this),
      )
      ..setRendererParams(
        <RendererParam>[
          new RendererParam.withShadowTechnique(_currentShadowTechnique)
        ],
      )
      ..setPresentationModeListener(
          _presentationModeListenerBinding.wrap(this));
  }

  @override
  void onStop() {
    _userControllerProxy?.ctrl?.close();
    _userWatcherImpl?.close();
    _keyboardCaptureListenerBindingSpaceBar.close();
    _keyboardCaptureListenerBindingS.close();
    _presentationModeListenerBinding.close();
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

  /// Call when reset is tapped.
  void resetTapped() {
    File dm = new File('/dev/misc/dmctl');
    print('dmctl exists? ${dm.existsSync()}');
    if (dm.existsSync()) {
      dm.writeAsStringSync('reboot', flush: true);
    }
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
    trace('logging in $accountId');
    encoder.startTimer(
      _kUserShellLoginTimeMetricId,
      _kNoOpEncodingId,
      'user_shell_login_timer_id',
      new DateTime.now().millisecondsSinceEpoch,
      _kCobaltTimerTimeout.inSeconds,
      (cobalt.Status status) {
        if (status != cobalt.Status.ok) {
          log.warning(
            'Failed to start timer metric '
                '$_kUserShellLoginTimeMetricId: $status. ',
          );
        }
      },
    );
    onLogin?.call();
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = new UserControllerProxy();
    _userWatcherImpl?.close();
    _userWatcherImpl = new UserWatcherImpl(onUserLogout: () {
      encoder.endTimer(
        'user_shell_log_out_timer_id',
        new DateTime.now().millisecondsSinceEpoch,
        _kCobaltTimerTimeout.inSeconds,
        (cobalt.Status status) {
          if (status != cobalt.Status.ok) {
            log.warning(
              'Failed to end timer metric '
                  'user_shell_log_out_timer_id: $status. ',
            );
          }
        },
      );
      log.info('UserPickerDeviceShell: User logged out!');
      onLogout();
    });

    final InterfacePair<ServiceProvider> serviceProvider =
        new InterfacePair<ServiceProvider>();
    _serviceProviderBinding.bind(this, serviceProvider.passRequest());

    _currentAccountId = accountId;
    UserShellInfo info = _userShellChooser.getNextUserShellInfo(
      _currentAccountId,
    );
    final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    final UserLoginParams params = new UserLoginParams(
      accountId: accountId,
      viewOwner: viewOwner.passRequest(),
      services: serviceProvider.passHandle(),
      userController: _userControllerProxy.ctrl.request(),
      userShellConfig: new AppConfig(url: info.name),
    );

    _updatePresentation(info);

    userProvider.login(params);

    _userControllerProxy.watch(_userWatcherImpl.getHandle());
    _loadingChildView = true;
    _childViewConnection = new ChildViewConnection(
      viewOwner.passHandle(),
      onAvailable: (ChildViewConnection connection) {
        trace('user shell available');
        log.info('UserPickerDeviceShell: Child view connection available!');
        _loadingChildView = false;
        connection.requestFocus();
        notifyListeners();
      },
      onUnavailable: (ChildViewConnection connection) {
        trace('user shell unavailable');
        log.info('UserPickerDeviceShell: Child view connection unavailable!');
        _loadingChildView = false;
        onLogout();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  /// |KeyboardCaptureListener|.
  @override
  void onEvent(KeyboardEvent ev) {
    log.info('Keyboard captured in device shell!');
    if (ev.codePoint == _kKeyCodeSpacebar &&
        _userControllerProxy.ctrl.isBound &&
        _userShellChooser != null) {
      UserShellInfo info = _userShellChooser.getNextUserShellInfo(
        _currentAccountId,
      );

      _updatePresentation(info);

      _userControllerProxy.swapUserShell(new AppConfig(url: info.name), () {});
    } else if (ev.codePoint == _kKeyCodeS) {
      // Toggles from unshadowed -> screenSpace -> shadowMap
      if (_currentShadowTechnique == ShadowTechnique.unshadowed) {
        _currentShadowTechnique = ShadowTechnique.screenSpace;
      } else if (_currentShadowTechnique == ShadowTechnique.screenSpace) {
        _currentShadowTechnique = ShadowTechnique.shadowMap;
      } else {
        _currentShadowTechnique = ShadowTechnique.unshadowed;
      }
      presentation.setRendererParams(
        <RendererParam>[
          new RendererParam.withShadowTechnique(_currentShadowTechnique)
        ],
      );
    } else if (ev.codePoint == _kKeyCodeL) {
      _currentClippingEnabled = !_currentClippingEnabled;
      enableClipping(_currentClippingEnabled);
    }
  }

  void _updatePresentation(UserShellInfo info) {
    setDisplayUsage(info.displayUsage);
    setDisplaySizeInMm(info.screenWidthMm, info.screenHeightMm);
  }

  /// |PresentationModeListener|.
  @override
  void onModeChanged() {
    getPresentationMode((PresentationMode mode) {
      log.info('Presentation mode changed to: $mode');
    });
  }

  /// Called when the the user shell logs out.
  void onLogout() {
    trace('logout');
    setDisplayUsage(DisplayUsage.kClose);
    setDisplaySizeInMm(0.0, 0.0);
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

  // |Presentation|.
  @override
  void setDisplayUsage(DisplayUsage usage) {
    presentation.setDisplayUsage(usage);
  }

  // |Presentation|.
  @override
  void setDisplaySizeInMm(num widthInMm, num heightInMm) {
    presentation.setDisplaySizeInMm(widthInMm, heightInMm);
  }

  // |Presentation|.
  @override
  void captureKeyboardEvent(KeyboardEvent eventToCapture,
      InterfaceHandle<KeyboardCaptureListener> listener) {
    presentation.captureKeyboardEvent(eventToCapture, listener);
  }

  /// |Presentation|.
  @override
  void getPresentationMode(GetPresentationModeCallback callback) {
    presentation.getPresentationMode(callback);
  }

  /// |Presentation|.
  @override
  void setPresentationModeListener(
      InterfaceHandle<PresentationModeListener> listener) {
    presentation.setPresentationModeListener(listener);
  }

  // |ServiceProvider|.
  @override
  void connectToService(String serviceName, Channel channel) {
    // TODO(SCN-595) mozart.Presentation is being renamed to ui.Presentation.
    if (serviceName == 'mozart.Presentation' ||
        serviceName == 'ui.Presentation') {
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

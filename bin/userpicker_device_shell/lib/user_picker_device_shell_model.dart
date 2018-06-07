// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl/fidl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fidl_cobalt/fidl.dart' as cobalt;
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_ui_gfx/fidl.dart';
import 'package:fidl_fuchsia_ui_input/fidl.dart' as input;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.device_shell/user_shell_chooser.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/modular.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:zircon/zircon.dart' show Channel;

import 'user_watcher_impl.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, ScopedModelDescendant, ModelFinder;

/// Function signature for GetPresentationMode callback
typedef GetPresentationModeCallback = void Function(PresentationMode mode);

/// HACKY way to retrofit.
typedef SetupCallback = void Function({
  VoidCallback addNewUser,
  VoidCallback loginAsGuest,
});

const Duration _kCobaltTimerTimeout = const Duration(seconds: 20);
const int _kNoOpEncodingId = 1;
const int _kUserShellLoginTimeMetricId = 14;
const int _kKeyModifierLeftCtrl = 8;
const int _kKeyModifierRightAlt = 64;
const int _kKeyCodeSpacebar = 32;
const int _kKeyCodeL = 108;
const int _kKeyCodeS = 115;
const Duration _kShowLoadingSpinnerDelay = const Duration(milliseconds: 500);

/// Contains all the relevant data for displaying the list of users and for
/// logging in and creating new users.
class UserPickerDeviceShellModel extends DeviceShellModel
    with TickerProviderModelMixin
    implements
        Presentation,
        ServiceProvider,
        KeyboardCaptureListenerHack,
        PointerCaptureListenerHack,
        PresentationModeListener {
  /// Called when the device shell stops.
  final VoidCallback onDeviceShellStopped;

  /// Called when wifi is tapped.
  final VoidCallback onWifiTapped;

  /// Called when setup is tapped
  final SetupCallback onSetup;

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
  final KeyboardCaptureListenerHackBinding
      _keyboardCaptureListenerBindingSpaceBar =
      new KeyboardCaptureListenerHackBinding();
  final KeyboardCaptureListenerHackBinding _keyboardCaptureListenerBindingS =
      new KeyboardCaptureListenerHackBinding();
  final KeyboardCaptureListenerHackBinding _keyboardCaptureListenerBindingL =
      new KeyboardCaptureListenerHackBinding();
  final PresentationModeListenerBinding _presentationModeListenerBinding =
      new PresentationModeListenerBinding();
  final PointerCaptureListenerHackBinding _pointerCaptureListenerBinding =
      new PointerCaptureListenerHackBinding();
  ShadowTechnique _currentShadowTechnique = ShadowTechnique.unshadowed;
  bool _currentClippingEnabled = true;
  bool _hasConfiguredUserShells = false;

  // Because this device shell only supports a single user logged in at a time,
  // we don't need to maintain separate ServiceProvider for each logged-in user.
  final ServiceProviderBinding _serviceProviderBinding =
      new ServiceProviderBinding();
  final List<PresentationBinding> _presentationBindings =
      <PresentationBinding>[];

  /// Constructor
  UserPickerDeviceShellModel({
    this.onDeviceShellStopped,
    this.onWifiTapped,
    this.onLogin,
    this.encoder,
    this.onSetup,
  }) : super() {
    // Check for last kernel panic
    File lastPanic = new File('/boot/log/last-panic.txt');
    if (lastPanic.existsSync()) {
      _showingKernelPanic = true;
      notifyListeners();
    }
  }

  /// The list of previously logged in accounts.
  List<Account> get accounts => _accounts;

  /// Scroll Controller for the user picker
  ScrollController get userPickerScrollController =>
      _userPickerScrollController;

  /// True if a user shell has been configured.
  bool get hasConfiguredUserShells => _hasConfiguredUserShells;

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
      ..captureKeyboardEventHack(
        const input.KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeSpacebar,
          modifiers: _kKeyModifierLeftCtrl,
          phase: input.KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingSpaceBar.wrap(this),
      )
      ..captureKeyboardEventHack(
        const input.KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeS,
          modifiers: _kKeyModifierLeftCtrl,
          phase: input.KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingS.wrap(this),
      )
      ..captureKeyboardEventHack(
        const input.KeyboardEvent(
          deviceId: 0,
          eventTime: 0,
          hidUsage: 0,
          codePoint: _kKeyCodeL,
          modifiers: _kKeyModifierRightAlt,
          phase: input.KeyboardEventPhase.pressed,
        ),
        _keyboardCaptureListenerBindingL.wrap(this),
      )
      ..capturePointerEventsHack(_pointerCaptureListenerBinding.wrap(this))
      ..setRendererParams(
        <RendererParam>[
          new RendererParam.withShadowTechnique(_currentShadowTechnique)
        ],
      )
      ..setPresentationModeListener(
          _presentationModeListenerBinding.wrap(this));

    _userShellChooser.init().then((_) async {
      _hasConfiguredUserShells = _userShellChooser.currentUserShell != null;
      _updatePresentation(_userShellChooser.currentUserShell);
      notifyListeners();
    });
  }

  @override
  void onStop() {
    _userControllerProxy?.ctrl?.close();
    _userWatcherImpl?.close();
    _keyboardCaptureListenerBindingSpaceBar.close();
    _keyboardCaptureListenerBindingS.close();
    _presentationModeListenerBinding.close();
    onDeviceShellStopped?.call();
    super.dispose();
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
      _updateShowLoadingSpinner();
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
    _updateShowLoadingSpinner();
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
        _updateShowLoadingSpinner();
        notifyListeners();
      },
    );
  }

  /// Start the setup flow to create a new user and login with that user
  void startSetupFlow() {
    _addingUser = true;
    _updateShowLoadingSpinner();
    notifyListeners();

    onSetup?.call(addNewUser: () {
      userProvider.addUser(
        IdentityProvider.google,
        (Account account, String errorCode) {
          if (errorCode == null) {
            login(account.id);
          } else {
            log.warning('ERROR adding user!  $errorCode');
          }
          _addingUser = false;
          _updateShowLoadingSpinner();
          notifyListeners();
        },
      );
    }, loginAsGuest: () {
      login(null);
      hideUserActions();
    });
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

    UserShellInfo info = _userShellChooser.currentUserShell;
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
    _updateShowLoadingSpinner();
    _childViewConnection = new ChildViewConnection(
      viewOwner.passHandle(),
      onAvailable: (ChildViewConnection connection) {
        trace('user shell available');
        log.info('UserPickerDeviceShell: Child view connection available!');
        _loadingChildView = false;
        _updateShowLoadingSpinner();
        connection.requestFocus();
        notifyListeners();
      },
      onUnavailable: (ChildViewConnection connection) {
        trace('user shell unavailable');
        log.info('UserPickerDeviceShell: Child view connection unavailable!');
        _loadingChildView = false;
        _updateShowLoadingSpinner();
        onLogout();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  /// |KeyboardCaptureListener|.
  @override
  void onEvent(input.KeyboardEvent ev) {
    log.info('Keyboard captured in device shell!');
    if (ev.codePoint == _kKeyCodeSpacebar &&
        (_userControllerProxy?.ctrl?.isBound ?? false) &&
        _userShellChooser != null) {
      if (_userShellChooser.swapUserShells()) {
        _updatePresentation(_userShellChooser.currentUserShell);
        _userControllerProxy.swapUserShell(
          new AppConfig(url: _userShellChooser.currentUserShell.name),
          () {},
        );
      }
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

  /// |PointerCaptureListener|.
  @override
  void onPointerEvent(input.PointerEvent event) {}

  void _updatePresentation(UserShellInfo info) {
    setDisplayUsage(info.displayUsage);
    setDisplaySizeInMm(info.screenWidthMm, info.screenHeightMm);
    if (info.autoLogin) {
      login(null);
    }
  }

  /// |PresentationModeListener|.
  @override
  void onModeChanged() {
    getPresentationMode((PresentationMode mode) {
      log.info('Presentation mode changed to: $mode');
      switch (mode) {
        case PresentationMode.tent:
          setDisplayRotation(180.0, true);
          break;
        case PresentationMode.tablet:
          // TODO(sanjayc): Figure out up/down orientation.
          setDisplayRotation(90.0, true);
          break;
        case PresentationMode.laptop:
        default:
          setDisplayRotation(0.0, true);
          break;
      }
    });
  }

  /// Called when the the user shell logs out.
  void onLogout() {
    trace('logout');
    refreshUsers();
    _childViewConnection = null;
    _serviceProviderBinding.close();
    for (PresentationBinding presentationBinding in _presentationBindings) {
      presentationBinding.close();
    }
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
  bool get showingLoadingSpinner => _showingLoadingSpinner;

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

  bool _showingLoadingSpinner = true;
  Timer _showLoadingSpinnerTimer;

  void _updateShowLoadingSpinner() {
    if (_accounts == null || _addingUser || _loadingChildView) {
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
  // ignore: avoid_positional_boolean_parameters
  void setDisplayRotation(double displayRotationDegrees, bool animate) {
    presentation.setDisplayRotation(displayRotationDegrees, animate);
  }

  // |Presentation|.
  @override
  void captureKeyboardEventHack(input.KeyboardEvent eventToCapture,
      InterfaceHandle<KeyboardCaptureListenerHack> listener) {
    presentation.captureKeyboardEventHack(eventToCapture, listener);
  }

  // |Presentation|.
  @override
  void capturePointerEventsHack(
      InterfaceHandle<PointerCaptureListenerHack> listener) {
    presentation.capturePointerEventsHack(listener);
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
      _presentationBindings.add(new PresentationBinding()
        ..bind(this, new InterfaceRequest<Presentation>(channel)));
    } else {
      log.warning(
          'UserPickerDeviceShell: received request for unknown service: $serviceName !');
      channel.close();
    }
  }
}

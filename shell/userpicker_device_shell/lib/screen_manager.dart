// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:application.services/application_launcher.fidl.dart';
import 'package:apps.modular.services.auth.account/account.fidl.dart';
import 'package:apps.modular.services.config/config.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import 'user_picker.dart';
import 'user_picker_buttons.dart';
import 'user_picker_screen.dart';
import 'user_shell_chooser.dart';
import 'user_watcher_impl.dart';

/// The root widget which displays all the other windows of this app.
class ScreenManager extends StatefulWidget {
  /// Called when the user logs out.
  final VoidCallback onLogout;

  /// Called when the user requests to add a user.
  final VoidCallback onAddUser;

  /// Called when the user requests to remove a user.
  final OnRemoveUser onRemoveUser;

  /// Launcher to launch the kernel panic module if needed.
  final ApplicationLauncher launcher;

  /// Constructor.
  ScreenManager({
    Key key,
    this.onLogout,
    this.onAddUser,
    this.onRemoveUser,
    @required this.launcher,
  })
      : super(key: key);

  @override
  _ScreenManagerState createState() => new _ScreenManagerState();
}

class _ScreenManagerState extends State<ScreenManager>
    with TickerProviderStateMixin {
  final TextEditingController _userNameController = new TextEditingController();
  final TextEditingController _serverNameController =
      new TextEditingController();
  final FocusNode _userNameFocusNode = new FocusNode();
  final FocusNode _serverNameFocusNode = new FocusNode();
  final Set<Account> _draggedUsers = new Set<Account>();
  final UserShellChooser _userShellChooser = new UserShellChooser();

  UserControllerProxy _userControllerProxy;
  UserWatcherImpl _userWatcherImpl;

  ChildViewConnection _childViewConnection;

  AnimationController _transitionAnimation;
  CurvedAnimation _curvedTransitionAnimation;

  bool _addingUser = false;
  bool _showKernelPanic = false;

  @override
  void initState() {
    super.initState();

    File lastPanic = new File('/boot/log/last-panic.txt');
    lastPanic.exists().then((bool exists) {
      if (exists) {
        setState(() {
          _showKernelPanic = true;
        });
      }
    });

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
    _curvedTransitionAnimation.addStatusListener(_onStatusChange);
  }

  @override
  void dispose() {
    _curvedTransitionAnimation.removeStatusListener(_onStatusChange);
    super.dispose();
    _userWatcherImpl?.close();
    _userWatcherImpl = null;
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = null;
  }

  void _onStatusChange(_) => setState(() {});

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = <Widget>[
      new UserPickerScreen(
        showBlackHole: _draggedUsers.isNotEmpty,
        userPicker: new UserPicker(
          onLoginRequest: _login,
          onAddUserStarted: _addUserStarted,
          onAddUserFinished: _addUserFinished,
          userNameController: _userNameController,
          serverNameController: _serverNameController,
          userNameFocusNode: _userNameFocusNode,
          serverNameFocusNode: _serverNameFocusNode,
          loggingIn: _addingUser ||
              (_childViewConnection != null &&
                  (_curvedTransitionAnimation.status ==
                          AnimationStatus.dismissed ||
                      _curvedTransitionAnimation.status ==
                          AnimationStatus.forward)),
          onUserDragStarted: (Account account) => setState(() {
                _draggedUsers.add(account);
              }),
          onUserDragCanceled: (Account account) => setState(() {
                _draggedUsers.remove(account);
              }),
        ),
        userPickerButtons: new UserPickerButtons(
          onAddUser: () {
            //TODO(apwilson): Remove the delay.  It's a workaround to raw
            // keyboard focus bug.
            new Timer(
              const Duration(milliseconds: 1000),
              () => FocusScope.of(context).requestFocus(_userNameFocusNode),
            );
            widget.onAddUser?.call();
          },
          onUserShellChange: () => setState(() {
                _userShellChooser.next();
              }),
          userShellAssetName: _userShellChooser.assetName,
        ),
        onRemoveUser: (Account account) => setState(() {
              _draggedUsers.remove(account);
              widget.onRemoveUser?.call(account);
            }),
      ),
    ];

    if (_showKernelPanic) {
      stackChildren.add(
        /// TODO(apwilson): Remove gesture detector and make kernel_panic
        /// hittestable when DNO-86 is fixed.
        new GestureDetector(
          onTap: () => setState(() {
                _showKernelPanic = false;
              }),
          child: new ApplicationWidget(
            url: 'file:///system/apps/kernel_panic',
            launcher: widget.launcher,
            onDone: () => setState(() {
                  _showKernelPanic = false;
                }),
            hitTestable: false,
          ),
        ),
      );
    }

    return new AnimatedBuilder(
      animation: _transitionAnimation,
      builder: (BuildContext context, Widget child) =>
          _childViewConnection == null
              ? child
              : new Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    new ChildView(connection: _childViewConnection),
                    new Opacity(
                      opacity: 1.0 - _curvedTransitionAnimation.value,
                      child: child,
                    ),
                  ],
                ),
      child: new Stack(fit: StackFit.expand, children: stackChildren),
    );
  }

  void _addUserStarted() => setState(() {
        _addingUser = true;
      });

  void _addUserFinished() => setState(() {
        _addingUser = false;
      });

  void _login(String accountId, UserProvider userProvider) {
    _userControllerProxy?.ctrl?.close();
    _userControllerProxy = new UserControllerProxy();
    _userWatcherImpl?.close();
    _userWatcherImpl = new UserWatcherImpl(onUserLogout: () {
      print('UserPickerDeviceShell: User logged out!');
      _handleLogout();
    });

    final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    final UserLoginParams params = new UserLoginParams()
      ..accountId = accountId
      ..viewOwner = viewOwner.passRequest()
      ..userController = _userControllerProxy.ctrl.request()
      ..userShellConfig = new AppConfig.init(_userShellChooser.appUrl, null);
    userProvider?.login(params);
    _userControllerProxy.watch(_userWatcherImpl.getHandle());

    setState(() {
      _childViewConnection = new ChildViewConnection(
        viewOwner.passHandle(),
        onAvailable: (ChildViewConnection connection) {
          print('UserPickerDeviceShell: Child view connection available!');
          _transitionAnimation.forward();
        },
        onUnavailable: (ChildViewConnection connection) {
          print('UserPickerDeviceShell: Child view connection unavailable!');
          _handleLogout();
        },
      );
    });
  }

  void _handleLogout() {
    setState(() {
      widget.onLogout?.call();
      _transitionAnimation.reverse();
      // TODO(apwilson): Should not need to remove the child view connection but
      // it causes a mozart deadlock in the compositor if you don't.
      _childViewConnection = null;
    });
  }
}

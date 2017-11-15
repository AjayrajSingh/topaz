// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.modular/modular.dart';
import 'package:lib.widgets/model.dart';

import '../widgets/window_media_query.dart';
import 'user_shell_model.dart';

/// A wrapper widget intended to be the root of the application that is
/// a [UserShell].  Its main purpose is to hold the [ApplicationContext] and
/// [UserShell] instances so they aren't garbage collected.
/// For convenience, [advertise] does the advertising of the app as a
/// [UserShell] to the rest of the system via the [ApplicationContext].
/// Also for convienence, the [UserShellModel] given to this widget as well as
/// an [IdleModel] will be made available to [_child] and [_child]'s descendants.
class UserShellWidget<T extends UserShellModel> extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [UserShell] services to.
  final ApplicationContext _applicationContext;

  /// The binding for the [UserShell] service implemented by [UserShellImpl].
  final UserShellBinding _userShellBinding;

  /// The binding for the [Lifecycle] service implemented by [UserShellImpl].
  final LifecycleBinding _lifecycleBinding;

  final IdleModel _idleModel = new IdleModel();

  /// The [UserShellImpl] whose services to [advertise].
  final UserShellImpl _userShell;

  /// The rest of the application.
  final Widget _child;

  final T _userShellModel;

  /// Constructor.
  factory UserShellWidget({
    ApplicationContext applicationContext,
    T userShellModel,
    Widget child,
  }) =>
      new UserShellWidget<T>._create(
        applicationContext: applicationContext,
        userShellModel: userShellModel,
        child: child,
        userShellBinding: new UserShellBinding(),
        lifecycleBinding: new LifecycleBinding(),
      );

  UserShellWidget._create({
    ApplicationContext applicationContext,
    T userShellModel,
    Widget child,
    UserShellBinding userShellBinding,
    LifecycleBinding lifecycleBinding,
  })
      : _applicationContext = applicationContext,
        _userShellModel = userShellModel,
        _child = child,
        _userShellBinding = userShellBinding,
        _lifecycleBinding = lifecycleBinding,
        _userShell = new UserShellImpl(
          onReady: userShellModel?.onReady,
          onStopping: userShellModel?.onStop,
          onNotify: userShellModel?.onNotify,
          watchAll: userShellModel?.watchAll,
          onStop: () {
            userShellBinding.close();
            lifecycleBinding.close();
          },
        );

  @override
  Widget build(BuildContext context) => new Directionality(
        textDirection: TextDirection.ltr,
        child: new WindowMediaQuery(
          child: new Listener(
            // TODO: determine idleness in a better way (DNO-147).
            onPointerDown: (_) => _idleModel.onUserInteraction(),
            onPointerMove: (_) => _idleModel.onUserInteraction(),
            onPointerUp: (_) => _idleModel.onUserInteraction(),
            onPointerCancel: (_) => _idleModel.onUserInteraction(),
            behavior: HitTestBehavior.translucent,
            child: new ScopedModel<IdleModel>(
              model: _idleModel,
              child: _userShellModel == null
                  ? _child
                  : new ScopedModel<T>(
                      model: _userShellModel,
                      child: _child,
                    ),
            ),
          ),
        ),
      );

  /// Advertises [_userShell] as a [UserShell] to the rest of the system via
  /// the [ApplicationContext].
  void advertise() {
    _applicationContext.outgoingServices
      ..addServiceForName(
        (InterfaceRequest<UserShell> request) =>
            _userShellBinding.bind(_userShell, request),
        UserShell.serviceName,
      )
      ..addServiceForName(
        (InterfaceRequest<Lifecycle> request) =>
            _lifecycleBinding.bind(_userShell, request),
        Lifecycle.serviceName,
      );
  }
}

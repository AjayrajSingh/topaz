// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
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
/// an [IdleModel] will be made available to [child] and [child]'s descendants.
class UserShellWidget<T extends UserShellModel> extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [UserShell] services to.
  final ApplicationContext applicationContext;

  final UserShellBinding _binding = new UserShellBinding();

  final IdleModel _idleModel = new IdleModel();

  /// The [UserShell] to [advertise].
  final UserShellImpl _userShell;

  /// The rest of the application.
  final Widget child;

  final T _userShellModel;

  /// Constructor.
  UserShellWidget({
    this.applicationContext,
    T userShellModel,
    this.child,
  })
      : _userShellModel = userShellModel,
        _userShell = new UserShellImpl(
          onReady: userShellModel?.onReady,
          onStopping: userShellModel?.onStop,
          onNotify: userShellModel?.onNotify,
          watchAll: userShellModel?.watchAll,
        ) {
    _userShell.onStop = _onStop;
  }

  void _onStop() {
    _binding.close();
  }

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
                  ? child
                  : new ScopedModel<T>(
                      model: _userShellModel,
                      child: child,
                    ),
            ),
          ),
        ),
      );

  /// Advertises [_userShell] as a [UserShell] to the rest of the system via
  /// the [ApplicationContext].
  void advertise() => applicationContext.outgoingServices.addServiceForName(
        (InterfaceRequest<UserShell> request) =>
            _binding.bind(_userShell, request),
        UserShell.serviceName,
      );
}

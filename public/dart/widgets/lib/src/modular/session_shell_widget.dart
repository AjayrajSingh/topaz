// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.user.dart/user.dart';
import 'package:lib.widgets/model.dart';
import 'package:fuchsia/fuchsia.dart' as fuchsia;

import '../widgets/window_media_query.dart';
import 'session_shell_model.dart';

export 'package:lib.app.dart/app.dart' show StartupContext;
export 'session_shell_model.dart' show SessionShellModel;

/// A wrapper widget intended to be the root of the application that is
/// a [SessionShell].  Its main purpose is to hold the [StartupContext] and
/// [SessionShell] instances so they aren't garbage collected.
/// For convenience, [advertise] does the advertising of the app as a
/// [SessionShell] to the rest of the system via the [StartupContext].
/// Also for convienence, the [SessionShellModel] given to this widget as well as
/// an [IdleModel] will be made available to [_child] and [_child]'s descendants.
class SessionShellWidget<T extends SessionShellModel> extends StatelessWidget {
  /// The [StartupContext] to [advertise] its [SessionShell] services to.
  final StartupContext _startupContext;

  /// The binding for the [Lifecycle] service implemented by [SessionShellImpl].
  final LifecycleBinding _lifecycleBinding;

  final IdleModel _idleModel = new IdleModel();

  /// The [SessionShellImpl] whose services to [advertise].
  final SessionShellImpl _sessionShell;

  /// The rest of the application.
  final Widget _child;

  final T _sessionShellModel;

  final VoidCallback _onWindowMetricsChanged;

  /// Constructor.
  factory SessionShellWidget({
    StartupContext startupContext,
    T sessionShellModel,
    VoidCallback onWindowMetricsChanged,
    Widget child,
  }) =>
      new SessionShellWidget<T>._create(
        startupContext: startupContext,
        sessionShellModel: sessionShellModel,
        onWindowMetricsChanged: onWindowMetricsChanged,
        child: child,
        lifecycleBinding: new LifecycleBinding(),
      );

  SessionShellWidget._create({
    StartupContext startupContext,
    T sessionShellModel,
    VoidCallback onWindowMetricsChanged,
    Widget child,
    LifecycleBinding lifecycleBinding,
  })  : _startupContext = startupContext,
        _sessionShellModel = sessionShellModel,
        _onWindowMetricsChanged = onWindowMetricsChanged,
        _child = child,
        _lifecycleBinding = lifecycleBinding,
        _sessionShell = new SessionShellImpl(
          startupContext: startupContext,
          onReady: sessionShellModel?.onReady,
          onStopping: sessionShellModel?.onStop,
          onNotify: sessionShellModel?.onNotify,
          watchAll: sessionShellModel?.watchAll,
          onStop: () {
            lifecycleBinding.close();
            fuchsia.exit(0);
          },
        );

  @override
  Widget build(BuildContext context) => new MaterialApp(
        home: new Material(
          child: new Directionality(
            textDirection: TextDirection.ltr,
            child: new WindowMediaQuery(
              onWindowMetricsChanged: _onWindowMetricsChanged,
              child: new Listener(
                // TODO: determine idleness in a better way (DNO-147).
                onPointerDown: (_) => _idleModel.onUserInteraction(),
                onPointerMove: (_) => _idleModel.onUserInteraction(),
                onPointerUp: (_) => _idleModel.onUserInteraction(),
                onPointerCancel: (_) => _idleModel.onUserInteraction(),
                behavior: HitTestBehavior.translucent,
                child: new ScopedModel<IdleModel>(
                  model: _idleModel,
                  child: _sessionShellModel == null
                      ? _child
                      : new ScopedModel<T>(
                          model: _sessionShellModel,
                          child: _child,
                        ),
                ),
              ),
            ),
          ),
        ),
      );

  /// Advertises [_sessionShell] as a [LifeCycle] to the rest of the system via
  /// the [StartupContext].
  void advertise() {
    _startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<Lifecycle> request) =>
          _lifecycleBinding.bind(_sessionShell, request),
      Lifecycle.$serviceName,
    );
  }
}

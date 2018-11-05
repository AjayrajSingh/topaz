// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.user.dart/user.dart';

export 'package:lib.app.dart/app.dart' show StartupContext;

/// A wrapper widget intended to be the root of the application that is
/// a [SessionShell].  Its main purpose is to hold the [StartupContext] and
/// [SessionShell] instances so they aren't garbage collected.
/// For convenience, [advertise] does the advertising of the app as a
/// [SessionShell] to the rest of the system via the [StartupContext].
class DankSessionShellWidget extends StatelessWidget {
  /// The [StartupContext] to [advertise] its [SessionShell] services to.
  final StartupContext _startupContext;

  /// The binding for the [Lifecycle] service implemented by [SessionShellImpl].
  final LifecycleBinding _lifecycleBinding;

  /// The binding for the [SessionShellPresentationProvider] service implemented
  /// by [SessionShellImpl].
  final _SessionShellPresentationProviderBindings _presentationProviderBindings;

  /// The [SessionShellImpl] whose services to [advertise].
  final DankSessionShellImpl _sessionShell;

  /// [Widget] for the rest of the Session Shell
  final Widget child;

  /// Callback that is fired when the [DankSessionShellImpl] is initialized and
  /// passes the [SessionShellContext]
  final OnDankSessionShellReady onReady;

  /// Constructor.
  factory DankSessionShellWidget({
    StartupContext startupContext,
    Widget child,
    OnDankSessionShellReady onReady,
  }) {
    return new DankSessionShellWidget._create(
      startupContext: startupContext,
      child: child,
      onReady: onReady,
      lifecycleBinding: new LifecycleBinding(),
      presentationProviderBindings:
          new _SessionShellPresentationProviderBindings(),
    );
  }

  DankSessionShellWidget._create({
    StartupContext startupContext,
    LifecycleBinding lifecycleBinding,
    _SessionShellPresentationProviderBindings presentationProviderBindings,
    this.child,
    this.onReady,
  })  : _startupContext = startupContext,
        _lifecycleBinding = lifecycleBinding,
        _presentationProviderBindings = presentationProviderBindings,
        _sessionShell = new DankSessionShellImpl(
          startupContext: startupContext,
          onReady: (SessionShellContext sessionShellContext) {
            onReady?.call(sessionShellContext);
          },
        );

  @override
  Widget build(BuildContext context) => child;

  /// Advertises [_sessionShell] as a [SessionShell] to the rest of the system via
  /// the [StartupContext].
  void advertise() {
    _startupContext.outgoingServices
      ..addServiceForName(
        (InterfaceRequest<Lifecycle> request) =>
            _lifecycleBinding.bind(_sessionShell, request),
        Lifecycle.$serviceName,
      )
      ..addServiceForName(
        (InterfaceRequest<SessionShellPresentationProvider> request) =>
            _presentationProviderBindings.bind(_sessionShell, request),
        SessionShellPresentationProvider.$serviceName,
      );
  }
}

/// Handles bindings for [SessionShellPresentationProviderBinding].
class _SessionShellPresentationProviderBindings {
  final List<SessionShellPresentationProviderBinding>
      _presentationProviderBindings =
      <SessionShellPresentationProviderBinding>[];

  void bind(DankSessionShellImpl sessionShell,
      InterfaceRequest<SessionShellPresentationProvider> request) {
    _presentationProviderBindings.add(
        new SessionShellPresentationProviderBinding()
          ..bind(sessionShell, request));
  }
}

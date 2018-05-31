// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.user.dart/user.dart';

export 'package:lib.app.dart/app.dart' show ApplicationContext;

/// A wrapper widget intended to be the root of the application that is
/// a [UserShell].  Its main purpose is to hold the [ApplicationContext] and
/// [UserShell] instances so they aren't garbage collected.
/// For convenience, [advertise] does the advertising of the app as a
/// [UserShell] to the rest of the system via the [ApplicationContext].
class DankUserShellWidget extends StatelessWidget {
  /// The [ApplicationContext] to [advertise] its [UserShell] services to.
  final ApplicationContext _applicationContext;

  /// The binding for the [UserShell] service implemented by [UserShellImpl].
  final UserShellBinding _userShellBinding;

  /// The binding for the [Lifecycle] service implemented by [UserShellImpl].
  final LifecycleBinding _lifecycleBinding;

  /// The binding for the [UserShellPresentationProvider] service implemented
  /// by [UserShellImpl].
  final _UserShellPresentationProviderBindings _presentationProviderBindings;

  /// The [UserShellImpl] whose services to [advertise].
  final DankUserShellImpl _userShell;

  /// [Widget] for the rest of the User Shell
  final Widget child;

  /// Callback that is fired when the [DankUserShellImpl] is initialized and
  /// passes the [UserShellContext]
  final OnDankUserShellReady onReady;

  /// Callback that is fired when the [DankUserShellImpl] is stopped.
  final VoidCallback onStop;

  /// Constructor.
  factory DankUserShellWidget({
    ApplicationContext applicationContext,
    Widget child,
    OnDankUserShellReady onReady,
    VoidCallback onStop,
  }) {
    return new DankUserShellWidget._create(
      applicationContext: applicationContext,
      child: child,
      onReady: onReady,
      onStop: onStop,
      userShellBinding: new UserShellBinding(),
      lifecycleBinding: new LifecycleBinding(),
      presentationProviderBindings:
          new _UserShellPresentationProviderBindings(),
    );
  }

  DankUserShellWidget._create({
    ApplicationContext applicationContext,
    UserShellBinding userShellBinding,
    LifecycleBinding lifecycleBinding,
    _UserShellPresentationProviderBindings presentationProviderBindings,
    this.child,
    this.onReady,
    this.onStop,
  })  : _applicationContext = applicationContext,
        _userShellBinding = userShellBinding,
        _lifecycleBinding = lifecycleBinding,
        _presentationProviderBindings = presentationProviderBindings,
        _userShell = new DankUserShellImpl(
          onStop: () {
            userShellBinding.close();
            lifecycleBinding.close();
            presentationProviderBindings.close();
            onStop?.call();
          },
          onReady: (UserShellContext userShellContext) {
            onReady?.call(userShellContext);
          },
        );

  @override
  Widget build(BuildContext context) => child;

  /// Advertises [_userShell] as a [UserShell] to the rest of the system via
  /// the [ApplicationContext].
  void advertise() {
    _applicationContext.outgoingServices
      ..addServiceForName(
        (InterfaceRequest<UserShell> request) =>
            _userShellBinding.bind(_userShell, request),
        UserShell.$serviceName,
      )
      ..addServiceForName(
        (InterfaceRequest<Lifecycle> request) =>
            _lifecycleBinding.bind(_userShell, request),
        Lifecycle.$serviceName,
      )
      ..addServiceForName(
        (InterfaceRequest<UserShellPresentationProvider> request) =>
            _presentationProviderBindings.bind(_userShell, request),
        UserShellPresentationProvider.$serviceName,
      );
  }
}

/// Handles bindings for [UserShellPresentationProviderBinding].
class _UserShellPresentationProviderBindings {
  final List<UserShellPresentationProviderBinding>
      _presentationProviderBindings = <UserShellPresentationProviderBinding>[];

  void bind(DankUserShellImpl userShell,
      InterfaceRequest<UserShellPresentationProvider> request) {
    _presentationProviderBindings.add(
        new UserShellPresentationProviderBinding()..bind(userShell, request));
  }

  void close() {
    for (UserShellPresentationProviderBinding binding
        in _presentationProviderBindings) {
      binding.close();
    }
    _presentationProviderBindings.clear();
  }
}

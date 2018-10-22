// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_auth/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.device.dart/device.dart';
import 'package:meta/meta.dart';

import '../widgets/window_media_query.dart';
import 'base_shell_model.dart';

/// A wrapper widget intended to be the root of the application that is
/// a [BaseShell].  Its main purpose is to hold the [StartupContext] and
/// [BaseShell] instances so they aren't garbage collected.
/// For convenience, [advertise] does the advertising of the app as a
/// [BaseShell] to the rest of the system via the [StartupContext].
/// Also for convienence, the [BaseShellModel] given to this widget
/// will be made available to [child] and [child]'s descendants.
class BaseShellWidget<T extends BaseShellModel> extends StatelessWidget {
  /// The [StartupContext] to [advertise] its [BaseShell] services to.
  final StartupContext startupContext;

  /// The bindings for the [BaseShell] service implemented by [BaseShellImpl].
  final Set<BaseShellBinding> _baseShellBindingSet =
      new Set<BaseShellBinding>();

  /// The bindings for the [Lifecycle] service implemented by [BaseShellImpl].
  final Set<LifecycleBinding> _lifecycleBindingSet =
      new Set<LifecycleBinding>();

  /// The [BaseShell] to [advertise].
  final BaseShellImpl _baseShell;

  /// The rest of the application.
  final Widget child;

  final T _baseShellModel;

  /// Constructor.
  BaseShellWidget({
    @required this.startupContext,
    T baseShellModel,
    AuthenticationContext authenticationContext,
    AuthenticationUiContext authenticationUiContext,
    this.child,
  })  : _baseShellModel = baseShellModel,
        _baseShell = _createBaseShell(
          baseShellModel,
          authenticationContext,
          authenticationUiContext,
        );

  @override
  Widget build(BuildContext context) => new MaterialApp(
        home: new Material(
          child: new Directionality(
            textDirection: TextDirection.ltr,
            child: new WindowMediaQuery(
              child: _baseShellModel == null
                  ? child
                  : new ScopedModel<T>(model: _baseShellModel, child: child),
            ),
          ),
        ),
      );

  /// Advertises [_baseShell] as a [BaseShell] to the rest of the system via
  /// the [StartupContext].
  void advertise() {
    startupContext.outgoingServices
      ..addServiceForName((InterfaceRequest<BaseShell> request) {
        BaseShellBinding binding = new BaseShellBinding()
          ..bind(_baseShell, request);
        _baseShellBindingSet.add(binding);
      }, BaseShell.$serviceName)
      ..addServiceForName((InterfaceRequest<Lifecycle> request) {
        LifecycleBinding binding = new LifecycleBinding()
          ..bind(_baseShell, request);
        _lifecycleBindingSet.add(binding);
      }, Lifecycle.$serviceName);
  }

  static BaseShell _createBaseShell(
    BaseShellModel baseShellModel,
    AuthenticationContext authenticationContext,
    AuthenticationUiContext authenticationUiContext,
  ) {
    return new BaseShellImpl(
      authenticationContext: authenticationContext,
      authenticationUiContext: authenticationUiContext,
      onReady: baseShellModel?.onReady,
      onStop: () {
        baseShellModel?.onStop?.call();
      },
    );
  }

  /// Cancels any authentication flow currently in progress.
  void cancelAuthenticationFlow() {
    _baseShell.closeAuthenticationContextBindings();
  }
}

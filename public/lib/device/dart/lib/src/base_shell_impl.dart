// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_auth/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ui_policy/fidl.dart';

/// Called when [BaseShell.initialize] occurs.
typedef OnBaseShellReady = void Function(
  UserProvider userProvider,
  BaseShellContext baseShellContext,
  Presentation presentation,
);

/// Called when [Lifecycle.terminate] occurs.
typedef OnBaseShellStop = void Function();

/// Implements a BaseShell for receiving the services a [BaseShell] needs to
/// operate.
class BaseShellImpl implements BaseShell, Lifecycle {
  final BaseShellContextProxy _baseShellContextProxy =
      new BaseShellContextProxy();
  final UserProviderProxy _userProviderProxy = new UserProviderProxy();
  final PresentationProxy _presentationProxy = new PresentationProxy();
  final Set<AuthenticationUiContextBinding> _authUiContextBindingSet =
      <AuthenticationUiContextBinding>{};

  /// Called when [initialize] occurs.
  final OnBaseShellReady onReady;

  /// Called when the [BaseShell] terminates.
  final OnBaseShellStop onStop;

  /// The [AuthenticationUiContext] is a new interface from
  /// |fuchsia::auth::TokenManager| service that provides a new authentication
  /// UI context to display signin and permission screens when requested.
  final AuthenticationUiContext authenticationUiContext;

  /// Constructor.
  BaseShellImpl({
    this.authenticationUiContext,
    this.onReady,
    this.onStop,
  });

  @override
  void initialize(
    InterfaceHandle<BaseShellContext> baseShellContextHandle,
    BaseShellParams baseShellParams,
  ) {
    if (onReady != null) {
      _baseShellContextProxy.ctrl.bind(baseShellContextHandle);
      _baseShellContextProxy.getUserProvider(_userProviderProxy.ctrl.request());
      if (baseShellParams.presentation.channel != null) {
        _presentationProxy.ctrl.bind(baseShellParams.presentation);
      }
      onReady(_userProviderProxy, _baseShellContextProxy, _presentationProxy);
    }
  }

  @override
  void terminate() {
    onStop?.call();
    _userProviderProxy.ctrl.close();
    _baseShellContextProxy.ctrl.close();
    for (AuthenticationUiContextBinding binding in _authUiContextBindingSet) {
      binding.close();
    }
  }

  @override
  void getAuthenticationUiContext(
    InterfaceRequest<AuthenticationUiContext> request,
  ) {
    AuthenticationUiContextBinding binding =
        new AuthenticationUiContextBinding()
          ..bind(authenticationUiContext, request);
    _authUiContextBindingSet.add(binding);
  }

  /// Closes all bindings to authentication contexts, effectively cancelling any ongoing
  /// authorization flows.
  void closeAuthenticationUiContextBindings() {
    for (AuthenticationUiContextBinding binding in _authUiContextBindingSet) {
      binding.close();
    }
    _authUiContextBindingSet.clear();
  }
}

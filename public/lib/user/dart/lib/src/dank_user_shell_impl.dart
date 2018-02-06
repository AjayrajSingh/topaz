// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'user_shell_impl.dart';

/// Called when [UserShell.initialize] occurs.
typedef void OnDankUserShellReady(
  UserShellContext userShellContext,
);

/// Implements a [UserShell].
/// This is a lightweight version that passes the [UserShellContextProxy]
/// through the [onReady] callback.
class DankUserShellImpl implements UserShell, Lifecycle {
  /// Constructor.
  DankUserShellImpl({
    this.onReady,
    this.onStop,
  });

  /// Binding for the actual UserShell interface object.
  final UserShellContextProxy _userShellContextProxy =
      new UserShellContextProxy();

  /// Called when [initialize] occurs.
  final OnDankUserShellReady onReady;

  /// Called at the conclusion of [Lifecycle.terminate].
  final OnUserShellStop onStop;

  @override
  void initialize(
    InterfaceHandle<UserShellContext> userShellContextHandle,
  ) {
    if (onReady != null) {
      _userShellContextProxy.ctrl.bind(userShellContextHandle);
      onReady(_userShellContextProxy);
    }
  }

  @override
  void terminate() {
    _userShellContextProxy.ctrl.close();
    onStop?.call();
  }
}

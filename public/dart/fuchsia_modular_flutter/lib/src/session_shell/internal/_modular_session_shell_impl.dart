// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_ui_views/fidl_async.dart' show ViewHolderToken;

/// Extends [modular.SessionShell]. Notifies session shell when a story's view
/// is attached and detached.
class ModularSessionShellImpl extends modular.SessionShell {
  final void Function(
    modular.ViewIdentifier,
    ViewHolderToken,
  ) _attachView2Callback;
  final void Function(modular.ViewIdentifier) _detachViewCallback;

  /// Constructor.
  ModularSessionShellImpl(this._attachView2Callback, this._detachViewCallback);

  @override
  Future<void> attachView2(
      modular.ViewIdentifier viewId, ViewHolderToken viewHolderToken) async {
    _attachView2Callback?.call(viewId, viewHolderToken);
  }

  @override
  Future<void> detachView(modular.ViewIdentifier viewId) async {
    _detachViewCallback?.call(viewId);
  }
}

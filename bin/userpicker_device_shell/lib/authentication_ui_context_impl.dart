// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_auth/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';

/// Called when an authentication overlay needs to be started.
typedef OnStartOverlay = void Function(InterfaceHandle<ViewOwner> viewOwner);

/// An [AuthenticationUiContext] which calls its callbacks to show an overlay.
class AuthenticationUiContextImpl extends AuthenticationUiContext {
  /// Called when an aunthentication overlay needs to be started.
  final OnStartOverlay _onStartOverlay;

  /// Called when an aunthentication overlay needs to be stopped.
  final VoidCallback _onStopOverlay;

  /// Builds an AuthenticationUiContext that takes |ViewOwner| callbacks to
  /// start and stop an authentication display overlay.
  AuthenticationUiContextImpl(
      {OnStartOverlay onStartOverlay, VoidCallback onStopOverlay})
      : _onStartOverlay = onStartOverlay,
        _onStopOverlay = onStopOverlay;

  @override
  void startOverlay(InterfaceHandle<ViewOwner> viewOwner) =>
      _onStartOverlay?.call(viewOwner);

  @override
  void stopOverlay() => _onStopOverlay?.call();
}

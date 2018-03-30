// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular_auth/modular_auth.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:fuchsia.fidl.views_v1_token/views_v1_token.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';

/// Called when an aunthentication overlay needs to be started.
typedef void OnStartOverlay(InterfaceHandle<ViewOwner> viewOwner);

/// An [AuthenticationContext] which calls its callbacks to show an overlay.
class AuthenticationContextImpl extends AuthenticationContext {
  /// Called when an aunthentication overlay needs to be started.
  final OnStartOverlay onStartOverlay;

  /// Called when an aunthentication overlay needs to be stopped.
  final VoidCallback onStopOverlay;

  /// Constructor.
  AuthenticationContextImpl({this.onStartOverlay, this.onStopOverlay});

  @override
  void startOverlay(InterfaceHandle<ViewOwner> viewOwner) =>
      onStartOverlay?.call(viewOwner);

  @override
  void stopOverlay() => onStopOverlay?.call();
}

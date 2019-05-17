// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';
import 'package:fidl_fuchsia_ui_views/fidl_async.dart';

typedef ChildViewConnectionCallback = void Function(
    ChildViewConnection connection);
typedef ChildViewConnectionStateCallback = void Function(
    ChildViewConnection connection, bool newState);

/// A connection to a child view.  It can be used to construct a [ChildView]
/// widget that will display the view's contents on their own layer.
class ChildViewConnection {
  /// SceneHost used to reference and render content from a remote Scene.
  SceneHost get sceneHost => _sceneHost;
  SceneHost _sceneHost;

  /// Creates this connection from a ViewHolderToken.
  ChildViewConnection(ViewHolderToken viewHolderToken,
      {ChildViewConnectionCallback onAvailable,
      ChildViewConnectionCallback onUnavailable,
      ChildViewConnectionStateCallback onStateChanged})
      : assert(viewHolderToken?.value != null) {
    if (viewHolderToken.value.isValid) {
      _sceneHost = SceneHost.fromViewHolderToken(
          viewHolderToken.value.passHandle(),
          (onAvailable == null)
              ? null
              : () {
                  onAvailable(this);
                },
          (onUnavailable == null)
              ? null
              : () {
                  onUnavailable(this);
                },
          (onStateChanged == null)
              ? null
              : (bool state) {
                  onStateChanged(this, state);
                });
    }
  }

  /// Requests that focus be transferred to the remote Scene represented by
  /// this connection.
  void requestFocus() {
    // TODO(SCN-1186): Use new mechanism to implement RequestFocus.
  }

  /// Sets properties on the remote Scene represented by this connection.
  void setChildProperties(double width, double height, double insetTop,
      double insetRight, double insetBottom, double insetLeft,
      {bool focusable = true}) {
    _sceneHost?.setProperties(
        width, height, insetTop, insetRight, insetBottom, insetLeft, focusable);
  }
}

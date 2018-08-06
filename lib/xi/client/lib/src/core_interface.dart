// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'view_interface.dart';

/// An interface for types which manage a connection to xi-core.
abstract class XiCoreProxy {
  /// Returns a [XiViewProxy] corresponding to the specified view
  XiViewProxy view(String viewId);

  /// Notify core that the client has started.
  void clientStarted();

  /// Request a new view. On completion, the future will contain the view
  /// identifier for the new view.
  Future<String> newView();

  /// Notify core that the specified view has been closed, and will receive
  /// no further events.
  void closeView(String viewId);

  /// Ask core to save the file backing the specified view.
  void save(String viewId, {String path});
}

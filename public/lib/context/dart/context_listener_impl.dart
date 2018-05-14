// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_modular/fidl.dart';
import 'package:fidl/fidl.dart';

/// Signature for callbacks that handle context updates.
typedef void UpdateCallback(ContextUpdate value);

/// Functional wrapper class for [ContextListener], using callbacks to
/// implement interface methods.
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();
  final UpdateCallback _onUpdate;

  /// Constructor.
  ContextListenerImpl(this._onUpdate);

  /// Gets the [InterfaceHandle] for this [ContextListener]
  /// implementation. The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  void onContextUpdate(ContextUpdate update) => _onUpdate(update);

  /// Closes this listener.
  void close() => _binding.close();
}

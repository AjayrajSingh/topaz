// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia/fuchsia.dart' as fuchsia;
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:meta/meta.dart';

/// Callback for [LifecycleImpl#onTerminate].
typedef LifecycleTerminateCallback = Future<Null> Function();

/// Impl for [fidl.Lifecycle].
class LifecycleImpl extends fidl.Lifecycle {
  /// Callback for when the system calls [terminate].
  final LifecycleTerminateCallback onTerminate;

  /// Constructor.
  LifecycleImpl({
    @required this.onTerminate,
  }) : assert(onTerminate != null);

  @override
  Future<Null> terminate() async {
    /// Await async events and errors to ensure a clean shutdown BEFORE exiting
    /// the program.
    await onTerminate();

    fuchsia.exit(0);
  }
}

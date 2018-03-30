// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:fuchsia' as fuchsia;

import 'package:fuchsia.fidl.modular/modular.dart' as fidl;
import 'package:meta/meta.dart';

/// Callback for [LifecycleImpl#onTerminate].
typedef Future<Null> LifecycleTerminateCallback();

/// Impl for [fidl.Lifecycle].
class LifecycleImpl extends fidl.Lifecycle {
  /// Callback for when the system calls [terminate].
  final LifecycleTerminateCallback onTerminate;

  /// Constructor.
  LifecycleImpl({
    @required this.onTerminate,
  })
      : assert(onTerminate != null);

  @override
  Future<Null> terminate() async {
    /// Await async events and errors to ensure a clean shutdown BEFORE exiting
    /// the program.
    await onTerminate();

    fuchsia.exit(0);
  }
}

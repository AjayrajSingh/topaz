// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_component/fidl.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_modular/fidl.dart';
import 'package:meta/meta.dart';

export 'package:fidl_modular/fidl.dart' show ModuleContext;
export 'package:fidl_component/fidl.dart'
    show ServiceProvider;

/// Callback for [ModuleImpl#onInitialize].
typedef void ModulelInitializeCallback(
  InterfaceHandle<ModuleContext> moduleContextHandle,
  InterfaceRequest<ServiceProvider> outgoingServicesRequest,
);

/// Impl for [Module].
class ModuleImpl implements Module {
  /// Callback for when the system initializes the module.
  final ModulelInitializeCallback onInitialize;

  /// Constructor.
  ModuleImpl({
    @required this.onInitialize,
  })
      : assert(onInitialize != null);

  @override
  void initialize(
    InterfaceHandle<ModuleContext> handle,
    InterfaceRequest<ServiceProvider> request,
  ) {
    // NOTE: request could be null.
    onInitialize(handle, request);
  }
}

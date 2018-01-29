// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:meta/meta.dart';

export 'package:lib.module.fidl/module_context.fidl.dart' show ModuleContext;
export 'package:lib.app.fidl/service_provider.fidl.dart' show ServiceProvider;

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

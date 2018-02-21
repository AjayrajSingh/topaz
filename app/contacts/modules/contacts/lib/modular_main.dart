// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';

import 'src/app.dart';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();

ModuleImpl _module = new ModuleImpl();

/// An implementation of the [Module] interface.
class ModuleImpl implements Module, Lifecycle {
  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  @override
  void initialize(InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceRequest<ServiceProvider> outgoingServices) {}

  @override
  void terminate() {
    _moduleBinding.close();
    _lifecycleBinding.close();
    exit(0);
  }
}

/// Entry point for this module.
void main() {
  _appContext.outgoingServices
    ..addServiceForName(
      (InterfaceRequest<Module> request) {
        _module.bindModule(request);
      },
      Module.serviceName,
    )
    ..addServiceForName(
      (InterfaceRequest<Lifecycle> request) {
        _module.bindLifecycle(request);
      },
      Lifecycle.serviceName,
    );

  runApp(new App());
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:isolate';

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.lifecycle/lifecycle.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.ledger.services.public/ledger.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:xi_widgets/widgets.dart';

import 'src/xi_fuchsia_client.dart';

void _log(String msg) {
  print('[xi_app] $msg');
}

dynamic _handleResponse(String description) {
  return (Status status) {
    if (status != Status.ok) {
      _log("$description: $status");
    }
  };
}

/// An implementation of the [Module] interface.
class ModuleImpl implements Module, Lifecycle {
  /// Constructor.
  ModuleImpl(this._ledgerRequest);

  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  final ModuleContextProxy _moduleContext = new ModuleContextProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final InterfaceRequest<Ledger> _ledgerRequest;

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  @override
  void initialize(
      InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceHandle<ServiceProvider> incomingServices,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    _log('ModuleImpl::initialize call');

    _moduleContext.ctrl.bind(moduleContextHandle);
    _moduleContext.getComponentContext(_componentContext.ctrl.request());
    _componentContext.getLedger(_ledgerRequest, _handleResponse("getLedger"));
  }

  @override
  void terminate() {
    _log('ModuleImpl::stop call');

    // Cleaning up.
    _moduleContext.ctrl.close();
    _moduleBinding.close();
    _lifecycleBinding.close();
    Isolate.current.kill();
  }
}

/// Main entry point to the example parent module.
void main() {
  _log('Module main called');

  InterfacePair<Ledger> pair = new InterfacePair<Ledger>();
  final ModuleImpl module = new ModuleImpl(pair.passRequest());

  kContext.outgoingServices
  ..addServiceForName(
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      module.bindModule(request);
    },
    Module.serviceName,
  )
  ..addServiceForName(
    (InterfaceRequest<Lifecycle> request) {
      module.bindLifecycle(request);
    },
    Lifecycle.serviceName,
  );

  _log('Starting Flutter app...');

  XiFuchsiaClient xi = new XiFuchsiaClient(pair.passHandle());

  runApp(new XiApp(
    xi: xi,
  ));
}

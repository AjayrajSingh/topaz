// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.services/service_provider.fidl.dart';
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
class ModuleImpl extends Module {
  /// Constructor.
  ModuleImpl(this._ledgerRequest);

  final ModuleBinding _binding = new ModuleBinding();
  final ModuleContextProxy _moduleContext = new ModuleContextProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final InterfaceRequest<Ledger> _ledgerRequest;

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bind(InterfaceRequest<Module> request) {
    _binding.bind(this, request);
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
  void stop(void callback()) {
    _log('ModuleImpl::stop call');

    // Cleaning up.
    _moduleContext.ctrl.close();

    // Invoke the callback to signal that the clean-up process is done.
    callback();

    _binding.close();
  }
}

/// Main entry point to the example parent module.
void main() {
  _log('Module main called');

  InterfacePair<Ledger> pair = new InterfacePair<Ledger>();
  final ModuleImpl module = new ModuleImpl(pair.passRequest());

  kContext.outgoingServices.addServiceForName(
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      module.bind(request);
    },
    Module.serviceName,
  );

  _log('Starting Flutter app...');

  XiFuchsiaClient xi = new XiFuchsiaClient(pair.passHandle());

  runApp(new XiApp(
    xi: xi,
  ));
}

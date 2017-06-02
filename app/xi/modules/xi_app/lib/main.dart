// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:xi_widgets/widgets.dart';

import 'src/xi_fuchsia_client.dart';

ModuleImpl _module;

void _log(String msg) {
  print('[xi_app] $msg');
}

/// An implementation of the [Module] interface.
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();
  final ModuleContextProxy _moduleContext = new ModuleContextProxy();

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
  }

  @override
  void stop(void callback()) {
    _log('ModuleImpl::stop call');

    // Cleaning up.
    _moduleContext.ctrl.close();

    // Invoke the callback to signal that the clean-up process is done.
    callback();
  }
}

/// Main entry point to the example parent module.
void main() {
  _log('Module main called');

  kContext.outgoingServices.addServiceForName(
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      if (_module != null) {
        _log('Module interface can only be provided once. '
            'Rejecting request.');
        request.channel.close();
        return;
      }
      _module = new ModuleImpl()..bind(request);
    },
    Module.serviceName,
  );

  _log('Starting Flutter app...');

  XiFuchsiaClient xi = new XiFuchsiaClient();

  runApp(new XiApp(
    xi: xi,
  ));
}

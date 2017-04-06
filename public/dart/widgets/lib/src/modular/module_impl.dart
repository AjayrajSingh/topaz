// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Called when [Module.initialize] occurs.
typedef void OnReady(
  ModuleContext moduleContext,
  Link link,
  ServiceProvider incomingServiceProvider,
);

/// Implements a Module for receiving the services a [Module] needs to
/// operate.  When [initialize] is called, the services it receives are routed
/// by this class to the various classes which need them.
class ModuleImpl extends Module {
  final ModuleContextProxy _moduleContextProxy = new ModuleContextProxy();
  final LinkProxy _linkProxy = new LinkProxy();
  final ServiceProviderProxy _incomingServiceProviderProxy =
      new ServiceProviderProxy();
  final ServiceProviderBinding _outgoingServiceProviderBinding =
      new ServiceProviderBinding();

  /// The [ServiceProvider] to provide when outgoing services are requested.
  final ServiceProvider outgoingServiceProvider;

  /// Called when [Module] is initialied with its services.
  final OnReady onReady;

  /// Called when [Module] is stopped.
  final VoidCallback onStop;

  /// Constuctor.
  ModuleImpl({this.outgoingServiceProvider, this.onReady, this.onStop});

  @override
  void initialize(
    InterfaceHandle<ModuleContext> moduleContext,
    InterfaceHandle<Link> link,
    InterfaceHandle<ServiceProvider> incomingServices,
    InterfaceRequest<ServiceProvider> outgoingServices,
  ) {
    if (onReady != null) {
      _moduleContextProxy.ctrl.bind(moduleContext);
      _linkProxy.ctrl.bind(link);

      if (incomingServices != null) {
        _incomingServiceProviderProxy.ctrl.bind(incomingServices);
      }

      onReady(_moduleContextProxy, _linkProxy, _incomingServiceProviderProxy);
    }

    if (outgoingServices != null && outgoingServiceProvider != null) {
      _outgoingServiceProviderBinding.bind(
        outgoingServiceProvider,
        outgoingServices,
      );
    }
  }

  @override
  void stop(void done()) {
    onStop?.call();
    _moduleContextProxy.ctrl.close();
    _linkProxy.ctrl.close();
    _incomingServiceProviderProxy.ctrl.close();
    _outgoingServiceProviderBinding.close();
    done();
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';

import 'package:fuchsia/peridot.dart';

/// A callback used by [SimpleModule] to communicate [Exception] events to
/// clients.
typedef void SimpleModuleExceptionCallback(Exception err);

/// A callback used to pass [JSON] decoded [Link] content
/// to clients.
typedef void SimpleModuleLinkUpdate(Map<String, dynamic> json);

/// A basic implementation of a [Module] that encapsulates boilerplate required
/// for Fuchsia's application model.
class SimpleModule {
  /// Called when an [Exception] is encountered.
  /// * [FormatException] be triggered by failed [JSON#decode].
  final SimpleModuleExceptionCallback onException;

  /// Called when the interanl [module]'s Link is updated.
  final SimpleModuleLinkUpdate onLinkUpdate;

  /// The [ModuleBinding] for the [module].
  final ModuleBinding moduleBinding = new ModuleBinding();

  /// The [LifecycleBinding] for the [module].
  final LifecycleBinding lifecycleBinding = new LifecycleBinding();

  ModuleImpl _module;
  ModuleContext _moduleContext;
  Link _link;
  ServiceProvider _incomingServiceProvider;

  /// The [ApplicationContext] encapsulates how the module exchanges services with
  /// the Fuchsia system. E.g. the Module service is exposed via this
  /// application context. Similarly, this module can access other services
  /// provided by the environment via application context.
  final ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  /// Construct a new [SimpleModule].
  SimpleModule({
    this.onLinkUpdate,
    this.onException,
  }) {
    _module = new ModuleImpl(
      applicationContext: applicationContext,
      onReady: handleReady,
      onStop: handleStop,
      onNotify: handleLinkChanged,
      watchAll: false,
    );
  }

  /// The [ModuleImpl] that interfaces with service requests.
  ModuleImpl get module => _module;

  /// The [ModuleContext] returned from the [ModuleImpl]'s startup.
  ModuleContext get moduleContext => _moduleContext;

  /// The [Link] returned from the [ModuleImpl]'s startup.
  Link get link => _link;

  /// The [incomingServiceProvider] returned from the [ModuleImpl]'s startup.
  ServiceProvider get incomingServiceProvider => _incomingServiceProvider;

  /// The handler for [ModuleImpl#onReady].
  void handleReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServiceProvider,
  ) {
    /// TODO(SO-920): Move these to public getters on the ModuleImpl.
    _moduleContext = moduleContext;
    _link = link;
    _incomingServiceProvider = incomingServiceProvider;

    // Signal module watchers it's go time.
    moduleContext.ready();
  }

  /// The handler for [ModuleImpl#onStop].
  void handleStop() {
    moduleContext.done();
    moduleBinding.close();
    lifecycleBinding.close();
  }

  /// The handler for [ModuleImpl#onNotify].
  void handleLinkChanged(String data) {
    if (data == null) {
      return;
    }

    dynamic json;
    try {
      json = JSON.decode(data);
    } on FormatException catch (err) {
      // TODO(SO-920): convert error into something nice like
      // LinkContentDecodeError.
      onException(err);
    }

    if (json != null && json is Map<String, dynamic>) {
      onLinkUpdate(json);
    } else {
      print('===> Link updated to an invlaid value: $json');
    }
  }

  /// Advertises [module] as a [Module] to the rest of the system via the
  /// [applicationContext].
  void advertise() {
    applicationContext.outgoingServices
      ..addServiceForName(
        (InterfaceRequest<Module> request) =>
            moduleBinding.bind(_module, request),
        Module.serviceName,
      )
      ..addServiceForName(
        (InterfaceRequest<Lifecycle> request) =>
            lifecycleBinding.bind(_module, request),
        Lifecycle.serviceName,
      );
  }
}

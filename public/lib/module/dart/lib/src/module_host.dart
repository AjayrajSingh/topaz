// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fuchsia.fidl.modular/modular.dart' as fidl;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.story.dart/story.dart';
import 'package:meta/meta.dart';

import 'module_context_client.dart';
import 'module_impl.dart';

export 'package:lib.app.dart/app.dart' show ServiceProviderImpl;

/// Result for the successful resolution of [ModuleHost#initialize].
class ModuleHostInitializeResult {
  /// The interface handle for the module context service.
  final InterfaceHandle<ModuleContext> moduleContextHandle;

  /// The outgoing service request the module was initialized with.
  final InterfaceRequest<ServiceProvider> outgoingServicesRequest;

  /// Constructor.
  ModuleHostInitializeResult({
    @required this.moduleContextHandle,
    @required this.outgoingServicesRequest,
  });
}

/// Hosts a [ModuleImpl] and manages the underlying [binding] connection.
class ModuleHost {
  /// The underlying [Binding] that connects the [impl] to it's client requests.
  final fidl.ModuleBinding binding = new fidl.ModuleBinding();

  /// The client for interacting with the ModuleContext service.
  final ModuleContextClient moduleContext = new ModuleContextClient();

  /// The default link client for this module.
  final LinkClient link = new LinkClient();

  /// The underlying impl that handles client requests.
  ModuleImpl impl;

  /// Constructor.
  ModuleHost() {
    impl = new ModuleImpl(onInitialize: _handleInitialize);

    binding
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  Completer<ModuleHostInitializeResult> _initialize;

  /// Initialize the module by connecting it's impl to
  /// [ApplicationContext#outgoingServices] and asynchronously resolving when
  /// the system calls the underlying impl's initialize method.
  Future<ModuleHostInitializeResult> initialize({
    @required ApplicationContext applicationContext,
  }) {
    assert(applicationContext != null);
    log.fine('#initialize()');

    // If for some reason this method has been called already return the pending
    // or completed future from the previous result instead of causing an error
    // by re-binding the impl.
    if (_initialize != null) {
      Exception err = new Exception('#listen() should only be called once');
      _initialize.completeError(err);
      return _initialize.future;
    } else {
      _initialize = new Completer<ModuleHostInitializeResult>();
    }

    applicationContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.Module> request) {
        try {
          binding.bind(impl, request);
        } on Exception catch (err, stackTrace) {
          _initialize.completeError(err, stackTrace);
        }
      },
      fidl.Module.$serviceName,
    );

    return _initialize.future;
  }

  /// Called by the framework (via [ModuleImpl]) when the module is successfully
  /// initialized by the framework. This method will successfully complete the
  /// pending future returned by calls to [initialize].
  Future<Null> _handleInitialize(
    InterfaceHandle<ModuleContext> moduleContextHandle,
    InterfaceRequest<ServiceProvider> outgoingServicesRequest,
  ) async {
    if (!_initialize.isCompleted) {
      log.info('module successfully initialized');

      _initialize.complete(new ModuleHostInitializeResult(
        moduleContextHandle: moduleContextHandle,
        outgoingServicesRequest: outgoingServicesRequest,
      ));
    }
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');

    if (_initialize != null && !_initialize.isCompleted) {
      _initialize.completeError(err);
      return;
    }

    // NOTE: this should be very a rare case.
    log.warning('binding connection failed outside of async control flow.');
    throw err;
  }

  void _handleBind() {
    log.fine('binding ready');
  }

  void _handleUnbind() {
    log.fine('binding unbound');
  }

  void _handleClose() {
    log.fine('binding closed');
  }

  /// Closes the underlying binding, usually called as a direct effect of
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc) being triggered by the
  /// framework.
  Future<Null> terminate() async {
    log.fine('terminate called, closing $binding');
    binding.close();
    return null;
  }
}

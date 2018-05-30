// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

import 'lifecycle_impl.dart';

export 'package:lib.app.dart/app.dart' show ServiceProviderImpl;

/// Hosts a [LifecycleImpl] and manages the underlying [binding] connection.
class LifecycleHost {
  /// The underlying [Binding] that connects the [impl] to client requests.
  final fidl.LifecycleBinding binding = new fidl.LifecycleBinding();

  /// Callback for when the system starts to shutdown this process.
  final LifecycleTerminateCallback onTerminate;

  /// The underlying impl that handles client requests by delegating to
  /// the [onTerminate] callback.
  LifecycleImpl impl;

  /// Constructor.
  LifecycleHost({
    @required this.onTerminate,
  })
      : assert(onTerminate != null) {
    impl = new LifecycleImpl(
      onTerminate: _handleTerminate,
    );

    binding
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  Completer<Null> _addService;

  /// Connect this LifecycleHost's impl to the
  /// [ApplicationContext#outgoingServices].
  Future<Null> addService({
    @required ApplicationContext applicationContext,
  }) {
    assert(applicationContext != null);

    log.fine('starting lifecycle host');

    // Do not create an error by rebinding if, for some reason, this method has been called already.
    if (_addService != null) {
      Exception err =
          new Exception('#addService() should only be called once.');
      _addService.completeError(err);
      return _addService.future;
    } else {
      _addService = new Completer<Null>();
    }

    applicationContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.Lifecycle> request) {
        try {
          binding.bind(impl, request);
        } on Exception catch (err, stackTrace) {
          _addService.completeError(err, stackTrace);
        }

        // There is no async way to hook into a success path once the lifecycle
        // service has been added. Additionally, errors can occur on the underlying
        // binding at anytime. Use a microtask to check for the future being
        // completed (with an error via _handleConnectionError) and complete
        // successfully if it hasn't.
        scheduleMicrotask(() {
          if (!_addService.isCompleted) {
            _addService.complete(null);
          }
        });
      },
      fidl.Lifecycle.$serviceName,
    );

    return _addService.future;
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');

    if (_addService != null && !_addService.isCompleted) {
      _addService.completeError(err);
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

  Future<Null> _handleTerminate() async {
    await Future.wait(<Future<Null>>[
      terminate(),
      onTerminate(),
    ]);
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

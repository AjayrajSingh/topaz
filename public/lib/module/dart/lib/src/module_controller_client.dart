// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl/fidl.dart' show ProxyError;
import 'package:lib.app.dart/logging.dart';

export 'package:fidl_fuchsia_modular/fidl.dart' show ModuleState;

/// Client wrapper for [fidl.ModuleController].
class ModuleControllerClient {
  /// The underlying [fidl.ModuleControllerProxy] used to send client requests
  /// to the [fidl.ModuleController] service.
  final fidl.ModuleControllerProxy proxy = new fidl.ModuleControllerProxy();

  /// Constructor.
  ModuleControllerClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  final Completer<Null> _bind = new Completer<Null>();

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;

  void _handleBind() {
    log.fine('proxy ready');
    _bind.complete(null);
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }

  void _handleClose() {
    log.fine('proxy closed, terminating link clients');
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  /// Focus the module.
  Future<Null> focus() async {
    Completer<Null> completer = new Completer<Null>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      await bound;
      proxy.focus();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// Defocus the module.
  Future<Null> defocus() async {
    Completer<Null> completer = new Completer<Null>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      await bound;
      proxy.defocus();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// Stop the module.
  Future<Null> stop() async {
    Completer<Null> completer = new Completer<Null>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      await bound;
      proxy.stop(completer.complete);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.fine('terminate called');
    proxy.ctrl.close();
  }
}

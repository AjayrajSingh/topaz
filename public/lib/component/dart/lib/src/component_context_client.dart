// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.component.fidl/component_context.fidl.dart' as fidl;
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.entity.dart/entity.dart';

/// A client wrapper for [fidl.ComponentContext].
class ComponentContextClient {
  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.ComponentContextProxy] service.
  final fidl.ComponentContextProxy proxy = new fidl.ComponentContextProxy();

  final EntityResolverClient _entityResolver = new EntityResolverClient();

  /// Constructor.
  ComponentContextClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;
  final Completer<Null> _bind = new Completer<Null>();

  /// See [fidl.ComponentContext#createEntityWithData].
  Future<String> createEntityWithData(Map<String, String> typeToData) {
    Completer<String> completer = new Completer<String>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    void onSuccess(String value) {
      if (!completer.isCompleted) {
        if (value != null) {
          completer.complete(value);
        } else {
          completer.completeError(new Exception('entity reference is null'));
        }
      }
    }

    try {
      proxy.createEntityWithData(typeToData, onSuccess);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  /// See [fidl.ComponentContext#getEntityResolver].
  Future<EntityResolverClient> getEntityResolver() async {
    if (_entityResolver.proxy.ctrl.isBound) {
      return _entityResolver;
    }

    Completer<EntityResolverClient> completer =
        new Completer<EntityResolverClient>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    _entityResolver.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.getEntityResolver(_entityResolver.proxy.ctrl.request());
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(_entityResolver);
      }
    });

    return completer.future;
  }

  void _handleConnectionError() {
    Exception err = new Exception('proxy connection failed');
    throw err;
  }

  void _handleBind() {
    log.fine('proxy ready');
    _bind.complete(null);
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  void _handleClose() {
    log.fine('proxy closed');
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
  }
}

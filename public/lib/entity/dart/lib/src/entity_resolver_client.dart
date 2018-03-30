// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart' as fidl;

import 'entity_client.dart';

/// Client wrapper for [fidl.EntityResolver].
class EntityResolverClient {
  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.EntityResolver] service.
  final fidl.EntityResolverProxy proxy = new fidl.EntityResolverProxy();

  final List<EntityClient> _entities = <EntityClient>[];

  /// Constructor.
  EntityResolverClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;
  final Completer<Null> _bind = new Completer<Null>();

  /// See [fidl.EntityResolver#resolveEntity].
  Future<EntityClient> resolveEntity(String ref) async {
    Completer<EntityClient> completer = new Completer<EntityClient>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    EntityClient entity = new EntityClient();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    entity.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    _entities.add(entity); // don't forget to close.

    try {
      proxy.resolveEntity(ref, entity.proxy.ctrl.request());
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(entity);
      }
    });

    return completer.future;
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
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

    for (EntityClient entity in _entities) {
      entity.terminate();
    }
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }
}

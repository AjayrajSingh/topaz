// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.component.dart/component.dart';
import 'package:lib.daisy.fidl/daisy.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart' as fidl;
import 'package:lib.story.dart/story.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:meta/meta.dart';

import 'module_controller_client.dart';

export 'package:lib.component.dart/component.dart' show ComponentContextClient;
export 'package:lib.daisy.fidl/daisy.fidl.dart';
export 'package:lib.surface.fidl/surface.fidl.dart';

/// When Module resolution fails.
class ResolutionException implements Exception {
  /// Information about the failure.
  final String message;

  /// Create a new [ResolutionException].
  ResolutionException(this.message);
}

/// Client wrapper for [fidl.ModuleContext].
///
/// TODO(SO-1125): implement all methods for ModuleContextClient
class ModuleContextClient {
  ComponentContextClient _componentContext;

  /// The underlying [Proxy] used to send client requests to the
  /// [fidl.ModuleContext] service.
  final fidl.ModuleContextProxy proxy = new fidl.ModuleContextProxy();
  final List<LinkClient> _links = <LinkClient>[];

  /// Constructor.
  ModuleContextClient() {
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

  /// Connects the passed in [LinkClient] via [fidl.ModuleContextProxy#getLink].
  // TODO(MS-1245): retrun an active link client automatically instead of passing one
  // through.
  Future<Null> getLink({
    @required LinkClient linkClient,
  }) async {
    log.fine('getLink: ${linkClient.name}');

    // Track all the link clients so they can be closed automatically when this
    // client is.
    _links.add(linkClient);

    Completer<Null> completer = new Completer<Null>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    InterfaceRequest<Link> request;
    try {
      // NOTE: Any async errors on the link's proxy should be managed by
      // LinkClient.
      request = linkClient.proxy.ctrl.request();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    try {
      proxy.getLink(linkClient.name, request);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// See [fidl.ModuleContext#ready].
  Future<Null> ready() async {
    Completer<Null> completer = new Completer<Null>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.ready();
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// See [fidl.ComponentContext#getComponentContext].
  Future<ComponentContextClient> getComponentContext() async {
    await bound;

    if (_componentContext != null) {
      return _componentContext;
    } else {
      _componentContext = new ComponentContextClient();
    }

    Completer<ComponentContextClient> completer =
        new Completer<ComponentContextClient>();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    _componentContext.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.getComponentContext(_componentContext.proxy.ctrl.request());
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(_componentContext);
      }
    });

    return completer.future;
  }

  /// See [fidl.ModuleContext#startDaisy].
  Future<ModuleControllerClient> startModule({
    @required String module,
    @required Daisy daisy,
    @required SurfaceRelation surfaceRelation,
  }) async {
    assert(module != null && module.isNotEmpty);
    assert(daisy != null);
    assert(surfaceRelation != null);

    Completer<ModuleControllerClient> completer =
        new Completer<ModuleControllerClient>();

    // TODO(): map results and reuse for subsequent calls, see getLink.
    ModuleControllerClient controller = new ModuleControllerClient();

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    // ignore: unawaited_futures
    controller.proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    void handleDaisyStatus(fidl.StartDaisyStatus status) {
      switch (status) {
        case fidl.StartDaisyStatus.success:
          completer.complete(controller);
          break;
        case fidl.StartDaisyStatus.noModulesFound:
          completer.completeError(new ResolutionException('no modules found'));
          break;
        default:
          completer.completeError(
              new ResolutionException('unknown status: $status'));
      }
    }

    try {
      proxy.startDaisyInShell(
        module,
        daisy,
        null,
        null,
        controller.proxy.ctrl.request(),
        surfaceRelation,
        handleDaisyStatus,
      );
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
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

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.fine('terminate called');
    proxy.ctrl.close();

    return Future
        .wait(_links.map((LinkClient link) => link.terminate()).toList())
        .then((_) => null);
  }
}

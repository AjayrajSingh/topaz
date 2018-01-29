// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.story.fidl/link.fidl.dart' as fidl;
import 'package:lib.logging/logging.dart';

import 'link_watcher_host.dart';

export 'package:lib.story.fidl/link.fidl.dart';
export 'link_watcher_host.dart';

/// Client wrapper for [fidl.Link].
///
/// TODO(SO-1126): implement all methods for LinkClient
class LinkClient {
  /// The underlying [Proxy] used to send client requests to the [fidl.Link]
  /// service.
  final fidl.LinkProxy proxy = new fidl.LinkProxy();

  /// The name of the link.
  final String name;

  /// Constructor.
  LinkClient({
    this.name,
  }) {
    proxy.ctrl.onConnectionError = _handleConnectionError;
    proxy.ctrl.onClose = _handleClose;
    proxy.ctrl.onBind = _handleBind;
  }

  final Completer<Null> _bind = new Completer<Null>();

  /// A future that completes when the [proxy] is bound.
  Future<Null> get bound => _bind.future;

  void _handleBind() {
    _bind.complete(null);
  }

  /// Get the decoded JSON value from [fidl.Link#get].
  Future<Object> get({
    List<String> path,
  }) async {
    log.fine('#get($path)');

    Completer<Object> completer = new Completer<Object>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    void callback(String data) {
      if (data == null || data.isEmpty) {
        completer.complete(null);
      } else {
        Object json;

        try {
          json = JSON.decode(data);
        } on Exception catch (err) {
          completer.completeError(err);
        }

        completer.complete(json);
      }
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.get(path, callback);
    } on Exception catch (err) {
      completer.completeError(err);
    }

    return completer.future;
  }

  /// Future based API for [fidl.Link#set].
  Future<Null> set({
    List<String> path,
    Object json,
  }) async {
    log.fine('#set($path, $json)');

    Completer<Null> completer = new Completer<Null>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    String data = JSON.encode(json);

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.set(path, data);
    } on Exception catch (err) {
      completer.completeError(err);
    }

    // Since there is no async success path for proxy.set (it is fire and
    // forget) the best way to check for success is pushing a job onto the end
    // of the async call stack and checking that the completer didn't enounter
    // and error, no errors at this stage == success.
    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  final List<LinkWatcherHost> _watchers = <LinkWatcherHost>[];

  /// Stream based API for [fidl.Link#watch] and [fidl.Link#watchAll].
  Stream<Object> watch({bool all: false}) {
    log.fine('#watch(all: $all)');

    // TODO(SO-1127): connect the stream's control plane to the underlying link watcher
    // so that it properly responds to clients requesting listen, pause, resume,
    // cancel.
    StreamController<Object> controller = new StreamController<Object>();

    // Get an initial value and emit it. Note that this call to #get is async
    // and will get the initial value once the module is "ready" and a proxy
    // connection to the proxy is successfully established.
    get().then(controller.add, onError: controller.addError);

    void handleNotify(String data) {
      log.finer('=> link value updated: $data');

      if (data == null || data.isEmpty) {
        // Subscribers to the update stream should filter invalid values like
        // null and invalid JSON structures per thier contracts.
        controller.add(null);
      }

      try {
        Object json = JSON.decode(data);

        if (json != null) {
          controller.add(json);
        }
      } on Exception catch (err, stackTrace) {
        controller
          ..addError(err, stackTrace)
          ..close();
      }
    }

    bound.then((_) {
      log.fine('link proxy bound, adding watcher');

      LinkWatcherHost watcher = new LinkWatcherHost(onNotify: handleNotify);
      _watchers.add(watcher);

      // Using Future#catchError allows any sync errors thrown within the onValue
      // block below to be caught without needing to add try-catch logic.
      watcher.wrap().then((InterfaceHandle<LinkWatcher> handle) {
        if (all) {
          proxy.watchAll(handle);
        } else {
          proxy.watch(handle);
        }
      }, onError: controller.addError).catchError(controller.addError);
    });

    return controller.stream;
  }

  void _handleClose() {
    for (LinkWatcherHost watcher in _watchers) {
      watcher.binding.close();
      _watchers.remove(watcher);
    }

    log.info('link watchers closed');
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
  }
}

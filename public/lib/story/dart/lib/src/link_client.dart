// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:lib.app.dart/logging.dart';

import 'link_watcher_host.dart';

export 'package:fidl_fuchsia_modular/fidl.dart';

export 'link_watcher_host.dart';

/// When a value for a given [ref] is not found.
class LinkClientNotFoundException extends Error {
  /// The id/ref that was not found.
  final String ref;

  /// Constructor.
  LinkClientNotFoundException(this.ref);

  @override
  String toString() {
    return 'LinkClientNotFoundException: no value found for "$ref"';
  }
}

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
    if (name == null) {
      /// TODO: add a better warning.
      log.warning('default links will be deprecated soon');
    }

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

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.get(path, completer.complete);
    } on Exception catch (err) {
      completer.completeError(err);
    }

    return completer.future;
  }

  /// Future based API for [fidl.Link#set].
  Future<Null> set({
    List<String> path,
    Object jsonData,
  }) async {
    log.fine('#set($path, $json)');

    Completer<Null> completer = new Completer<Null>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    String data = json.encode(jsonData);

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
  final List<StreamController<String>> _streams = <StreamController<String>>[];
  bool _receivedInitialValue = false;

  /// Stream based API for [fidl.Link#watch] and [fidl.Link#watchAll].
  Stream<String> watch({bool all = false}) {
    log.fine('#watch(all: $all)');

    // TODO(SO-1127): connect the stream's control plane to the underlying link watcher
    // so that it properly responds to clients requesting listen, pause, resume,
    // cancel.
    StreamController<String> controller = new StreamController<String>();
    _streams.add(controller);

    bound.then((_) {
      log.fine('link proxy bound, adding watcher');

      LinkWatcherHost watcher = new LinkWatcherHost(onNotify: (String data) {
        // TODO: remove when MI4-940 is done
        bool isInitialNullData =
            (data == null || data == 'null') && !_receivedInitialValue;
        if (!isInitialNullData) {
          _receivedInitialValue = true;
          controller.add(data);
        }
      });
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

  /// See [fidl.Link#setEntity].
  Future<Null> setEntity(String ref) async {
    assert(ref != null);
    assert(ref.isNotEmpty);

    Completer<Null> completer = new Completer<Null>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    try {
      proxy.setEntity(ref);
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

  /// See [fidl.Link#getEntity].
  Future<String> getEntity() async {
    Completer<String> completer = new Completer<String>();

    try {
      await bound;
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
      return completer.future;
    }

    // ignore: unawaited_futures
    proxy.ctrl.error.then((ProxyError err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    void handleEntity(String ref) {
      completer.complete(ref);
    }

    try {
      proxy.getEntity(handleEntity);
    } on Exception catch (err) {
      completer.completeError(err);
    }

    return completer.future;
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.info('terminate called');
    proxy.ctrl.close();
    return;
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  void _handleClose() {
    log.fine('proxy closed');
    for (LinkWatcherHost watcher in _watchers) {
      watcher.terminate();
    }
    _watchers.clear();

    for (StreamController<String> stream in _streams) {
      stream.close();
    }

    log.info('link watchers closed');
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:fidl/fidl.dart' show ProxyError, InterfaceHandle;
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

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

  final _streams = <StreamController<fidl.ModuleState>>[];
  final _watchers = <_ModuleWatcher>[];

  /// Watch the module for [ModuleState] changes.
  Stream<fidl.ModuleState> watch() {
    // TODO(SO-1127): connect the stream's control plane to the underlying link watcher
    // so that it properly responds to clients requesting listen, pause, resume,
    // cancel.
    var controller = new StreamController<fidl.ModuleState>();
    _streams.add(controller);

    bound.then(
      (_) {
        log.fine('module controller proxy bound, adding watcher');
        var watcher = new _ModuleWatcher(onStateChange: controller.add);
        _watchers.add(watcher);

        var handle = watcher.wrap();
        proxy.watch(handle);
      },
      onError: controller.addError,
    ).catchError(controller.addError);

    return controller.stream;
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
    var futures = _streams.map((s) => s.close()).toList()
      ..addAll(_watchers.map((w) => w.terminate()));
    return Future.wait(futures);
  }
}

typedef _ModuleWatcherHandleStateChange = void Function(fidl.ModuleState state);

class _ModuleWatcherImpl extends fidl.ModuleWatcher {
  final _ModuleWatcherHandleStateChange _onStateChange;

  _ModuleWatcherImpl({
    @required onStateChange,
  })  : assert(onStateChange != null),
        _onStateChange = onStateChange;

  @override
  void onStateChange(fidl.ModuleState state) => _onStateChange(state);
}

class _ModuleWatcher {
  final _ModuleWatcherHandleStateChange onStateChange;

  final fidl.ModuleWatcherBinding binding = new fidl.ModuleWatcherBinding();

  _ModuleWatcherImpl impl;

  _ModuleWatcher({
    @required this.onStateChange,
  }) : assert(onStateChange != null) {
    impl = _ModuleWatcherImpl(onStateChange: onStateChange);

    binding
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');

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

  InterfaceHandle<fidl.ModuleWatcher> wrap() {
    var handle = binding.wrap(impl);

    // TODO(FIDL-217): binding.wrap should use exceptions instead of a null value for
    // failure modes.
    if (handle == null) {
      Exception err = new Exception('failed to wrap ModuleWatcherImpl');
      throw err;
    }

    return handle;
  }

  Future<Null> terminate() async {
    log.fine('terminate called, closing $binding');
    binding.close();
    return null;
  }
}

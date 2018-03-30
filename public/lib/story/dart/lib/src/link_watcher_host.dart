// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart' as fidl;
import 'package:meta/meta.dart';

import 'link_watcher_impl.dart';

export 'package:lib.story.fidl/link.fidl.dart';

/// Hosts a [LinkWatcherImpl] and manages the underlying [binding].
class LinkWatcherHost {
  /// The [Binding] that connects the [impl] to client requests.
  final fidl.LinkWatcherBinding binding = new fidl.LinkWatcherBinding();

  /// Callback for when the Link content value updates.
  final LinkWatcherNotifyCallback onNotify;

  /// The impl that handles client requests by delegating to the [onNotify]
  /// callback.
  LinkWatcherImpl impl;

  /// Constructor.
  LinkWatcherHost({
    @required this.onNotify,
  })
      : assert(onNotify != null) {
    impl = new LinkWatcherImpl(
      onNotify: onNotify,
    );

    binding
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  Completer<InterfaceHandle<fidl.LinkWatcher>> _wrap;

  /// Async version of binding.wrap()
  Future<InterfaceHandle<fidl.LinkWatcher>> wrap() {
    if (_wrap != null) {
      Exception err = new Exception(
          'failing due to rebind attempt on an active connection');
      _wrap.completeError(err);
      return _wrap.future;
    } else {
      _wrap = new Completer<InterfaceHandle<fidl.LinkWatcher>>();
    }

    InterfaceHandle<fidl.LinkWatcher> handle;
    try {
      handle = binding.wrap(impl);
    } on Exception catch (err, stackTrace) {
      _wrap.completeError(err, stackTrace);
      return _wrap.future;
    }

    // TODO: binding.wrap should use exceptions instead of a null value for
    // failure modes.
    if (handle == null) {
      Exception err = new Exception('failed to wrap LinkWatcherImpl');
      _wrap.completeError(err);
    }

    // Give the async errors a chance to bubble before resolving with a success.
    scheduleMicrotask(() {
      if (!_wrap.isCompleted) {
        _wrap.complete(handle);
      }
    });

    return _wrap.future;
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');

    if (_wrap != null && !_wrap.isCompleted) {
      _wrap.completeError(err);
      return;
    }

    log.warning('binding connection failed outside of async control flow.');
    throw err;
  }

  void _handleBind() {
    log.fine('binding ready');
  }

  void _handleUnbind() {
    log.fine('binding unbound');
    _reset();
  }

  void _handleClose() {
    log.fine('binding closed');
    _reset();
  }

  void _reset() {
    // _wrap is reset so it can be called again without returning the previous,
    // unbound interface handle.
    _wrap = null;
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

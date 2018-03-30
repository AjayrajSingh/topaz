// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

/// A client wrapper class for fidl service proxies that extend [Proxy<T>] where
/// [T] is a FIDL interface.
abstract class ServiceClient<T> {
  final Completer<Null> _bind = new Completer<Null>();
  final Proxy<T> _proxy;

  /// Creates a new instance of [ServiceClient]
  ServiceClient(Proxy<T> proxy)
      : assert(proxy != null),
        _proxy = proxy {
    _proxy.ctrl
      ..onBind = handleBind
      ..onUnbind = handleUnbind
      ..onClose = handleClose
      ..onConnectionError = handleConnectionError;
  }

  /// The fidl [Proxy] for the service we want to connect to
  Proxy<T> get proxy => _proxy;

  /// Whether or not the service proxy has connected
  bool get bound => _bind.isCompleted;

  /// Called when the client is bound to the service implementation, override
  /// this method to add more functionality
  @mustCallSuper
  void handleBind() {
    log.fine('Bound');
    _bind.complete(null);
  }

  /// Called when the client is unbound from the service implementation,
  /// override this method to add more functionality
  void handleUnbind() {
    log.fine('Unbound');
  }

  /// Called when the client connection to the service implementation is closed,
  /// override this method to add more functionality
  void handleClose() {
    log.fine('Close');
  }

  /// Called when an error is propagated along the service connection channel,
  /// override this method to add more functionality
  void handleConnectionError() {
    log.fine('Error');
    throw new Exception('binding connection failed');
  }

  /// Handles tear down operations and closes open channels
  @mustCallSuper
  Future<Null> terminate() async {
    if (_bind.isCompleted && proxy.ctrl.isBound) {
      proxy.ctrl.close();
    }
  }
}

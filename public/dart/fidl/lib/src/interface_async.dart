// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'interface.dart';

/// An enum describing the state of a proxy.
enum ProxyState {
  /// The proxy has not yet been bound.
  unbound,

  /// The proxy has been bound to a channel.
  bound,

  /// An error has occurred.
  error,

  /// The proxy has been closed.
  closed
}

/// A controller for Future based proxies.
class AsyncProxyController<T, SYNC> {
  final ProxyController<SYNC> _syncCtrl;

  ProxyState _currentState = ProxyState.unbound;
  final StreamController<ProxyState> _stateChanges =
      new StreamController.broadcast();

  /// Construct an AsyncProxyController that wraps a ProxyController.
  AsyncProxyController(this._syncCtrl) {
    _syncCtrl
      ..onBind = (() => _changeState(ProxyState.bound))
      ..onUnbind = (() => _changeState(ProxyState.unbound))
      ..onConnectionError = (() => _changeState(ProxyState.error))
      ..onClose = (() => _changeState(ProxyState.closed));
  }

  /// Creates an interface request whose peer is bound to this interface proxy.
  ///
  /// Creates a channel pair, binds one of the channels to this object, and
  /// returns the other channel. Calls to the proxy will be encoded as messages
  /// and sent to the returned channel.
  ///
  /// The proxy must not already have been bound.
  InterfaceRequest<T> request() =>
      new InterfaceRequest<T>(_syncCtrl.request().passChannel());

  /// Binds the proxy to the given interface handle.
  ///
  /// Calls to the proxy will be encoded as messages and sent over the channel
  /// underlying the given interface handle.
  ///
  /// This object must not already be bound.
  ///
  /// The `interfaceHandle` parameter must not be null. The `channel` property
  /// of the given `interfaceHandle` must not be null.
  void bind(InterfaceHandle<T> interfaceHandle) =>
      _syncCtrl.bind(new InterfaceHandle<SYNC>(interfaceHandle.passChannel()));

  /// Unbinds the proxy and returns the unbound channel as an interface handle.
  ///
  /// Calls on the proxy will no longer be encoded as messages on the bound
  /// channel.
  ///
  /// The proxy must have previously been bound (e.g., using [bind]).
  InterfaceHandle<T> unbind() =>
      new InterfaceHandle<T>(_syncCtrl.unbind().passChannel());

  /// Close the channel bound to the proxy.
  ///
  /// The proxy must have previously been bound (e.g., using [bind]).
  void close() => _syncCtrl.close();

  /// The current state of the proxy.
  ProxyState get currentState => _currentState;

  /// A broadcast stream that notifies of proxy state changes.
  Stream<ProxyState> get stateChanges => _stateChanges.stream;

  void _changeState(ProxyState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateChanges.add(newState);
    }
  }

  /// The service name associated with [T], if any.
  ///
  /// Corresponds to the `[ServiceName]` attribute in the FIDL interface
  /// definition.
  ///
  /// This string is typically used with the `ServiceProvider` interface to
  /// request an implementation of [T].
  String get $serviceName => _syncCtrl.$serviceName;
}

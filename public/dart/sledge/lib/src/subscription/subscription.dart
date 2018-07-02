// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import '../document/change.dart';
import '../ledger_helpers.dart';

/// changes to Ledger.
class Subscription extends ledger.PageWatcher {
  final ledger.PageProxy _pageProxy;
  final ledger.PageSnapshotProxy _snapshotProxy;
  final ledger.PageWatcherBinding _pageWatcherBinding =
      new ledger.PageWatcherBinding();
  final void Function(Change change) _applyChangeCallback;
  final Change _currentChange = new Change();

  /// Register a watcher for Ledger page, which pass all changes to
  /// _applyChangeCallback.
  Subscription(this._pageProxy, LedgerPageSnapshotFactory snapshotFactory,
      this._applyChangeCallback, Completer<bool> subscriptionCompleter)
      : _snapshotProxy = snapshotFactory.newInstance() {
    Completer<ledger.Status> completer = new Completer<ledger.Status>();
    _pageProxy.getSnapshot(
      _snapshotProxy.ctrl.request(),
      Uint8List(0),
      _pageWatcherBinding.wrap(this),
      completer.complete,
    );

    completer.future.then((ledger.Status status) {
      if (status != ledger.Status.ok) {
        subscriptionCompleter.complete(false);
      }
      subscriptionCompleter.complete(true);
    });
  }

  @override
  void onChange(ledger.PageChange pageChange, ledger.ResultState resultState,
      void callback(InterfaceRequest<ledger.PageSnapshot> snapshotRequest)) {
    _currentChange.addAll(getChangeFromPageChange(pageChange));

    // For a given change, [onChange] can be called multiple times.
    if (resultState == ledger.ResultState.completed ||
        resultState == ledger.ResultState.partialCompleted) {
      _applyChangeCallback(_currentChange);
      _currentChange.clear();
    }

    callback(null);
  }

  // TODO: use it.
  /// Ends subscription.
  void unsubscribe() {
    _pageWatcherBinding?.close();
    _snapshotProxy.ctrl.close();
  }
}

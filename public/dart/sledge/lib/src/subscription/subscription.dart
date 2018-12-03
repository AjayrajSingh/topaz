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
  final ledger.PageWatcherBinding _pageWatcherBinding;
  final void Function(Change change) _applyChangeCallback;
  final Change _currentChange = new Change();

  /// Register a watcher for Ledger page, which pass all changes to
  /// _applyChangeCallback.
  Subscription(this._pageProxy, LedgerObjectsFactory ledgerObjectsFactory,
      this._applyChangeCallback, Completer<bool> subscriptionCompleter)
      : _snapshotProxy = ledgerObjectsFactory.newPageSnapshotProxy(),
        _pageWatcherBinding = ledgerObjectsFactory.newPageWatcherBinding() {
    Completer<ledger.Status> completer = new Completer<ledger.Status>();
    _pageProxy.getSnapshot(
      _snapshotProxy.ctrl.request(),
      new Uint8List(0),
      _pageWatcherBinding.wrap(this),
      completer.complete,
    );

    completer.future.then((ledger.Status status) {
      if (subscriptionCompleter.isCompleted) {
        // If an error occurs, `subscriptionCompleter` may have been completed
        // by the caller before `completer` has ran.
        return;
      }
      bool subscriptionSuccesfull = status == ledger.Status.ok;
      subscriptionCompleter.complete(subscriptionSuccesfull);
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

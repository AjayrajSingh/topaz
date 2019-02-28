// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.widgets.dart/model.dart';

import '../ledger_helpers.dart';

/// The model for the todo list module.
class TodoListModel extends Model implements ledger.PageWatcher {
  final Random _random = new Random(new DateTime.now().millisecondsSinceEpoch);

  final ledger.PageWatcherBinding _pageWatcherBinding =
      new ledger.PageWatcherBinding();

  final ledger.LedgerProxy _ledger = new ledger.LedgerProxy();

  final ledger.PageProxy _page = new ledger.PageProxy();

  /// The todo items. The source of truth is Ledger, so [_items] should never be
  /// modified directly.
  Map<List<int>, String> _items = <List<int>, String>{};

  /// Retrieves the todo items.
  Map<List<int>, String> get items => _items;

  /// Call this method to connect the model
  void connect(ComponentContextProxy componentContext) {
    _ledger.ctrl.onConnectionError = () {
      print('[Todo List] Ledger disconnected.');
    };
    componentContext.getLedger(
      _ledger.ctrl.request(),
    );
    _ledger.getRootPageNew(_page.ctrl.request());

    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();
    _page.getSnapshot(
      snapshot.ctrl.request(),
      new Uint8List(0),
      _pageWatcherBinding.wrap(this),
      handleLedgerResponse('Watch'),
    );

    _readItems(snapshot);
  }

  /// Call when the module should be terminated.
  void onTerminate() {
    _pageWatcherBinding.close();
    _ledger.ctrl.close();
    _page.ctrl.close();
  }

  /// Implementation of PageWatcher.onChange().
  @override
  void onChange(ledger.PageChange pageChange, ledger.ResultState resultState,
      void callback(InterfaceRequest<ledger.PageSnapshot> snapshotRequest)) {
    if (resultState != ledger.ResultState.completed &&
        resultState != ledger.ResultState.partialStarted) {
      print(
          '[Todo List] Unexpected result state in Ledger watcher: $resultState');
      callback(null);
      return;
    }
    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();
    callback(snapshot.ctrl.request());
    _readItems(snapshot);
  }

  /// Marks the item of the given [id] as done.
  void markItemDone(List<int> id) {
    _page.delete(id, handleLedgerResponse('Delete'));
  }

  /// Adds a new todo item with the given [content].
  void addItem(String content) {
    _page.put(_makeKey(), utf8.encode(content), handleLedgerResponse('Put'));
  }

  void _readItems(ledger.PageSnapshotProxy snapshot) {
    getEntriesFromSnapshot(snapshot,
        (ledger.Status status, Map<List<int>, String> items) {
      if (handleLedgerResponse('getEntries')(status)) {
        return;
      }

      _items = items;
      notifyListeners();
      snapshot.ctrl.close();
    });
  }

  Uint8List _makeKey() {
    Uint8List key = new Uint8List(16);
    for (int i = 0; i < 16; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }
}

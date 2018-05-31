// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:fidl/fidl.dart';
import 'package:fidl_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.widgets/modular.dart';

import '../ledger_helpers.dart';

/// The model for the todo list module.
class TodoListModuleModel extends ModuleModel implements ledger.PageWatcher {
  final Random _random = new Random(new DateTime.now().millisecondsSinceEpoch);

  final ComponentContextProxy _componentContext = new ComponentContextProxy();

  final ledger.PageWatcherBinding _pageWatcherBinding =
      new ledger.PageWatcherBinding();

  final ledger.LedgerProxy _ledger = new ledger.LedgerProxy();

  final ledger.PageProxy _page = new ledger.PageProxy();

  /// The todo items. The source of truth is Ledger, so [_items] should never be
  /// modified directly.
  Map<List<int>, String> _items = <List<int>, String>{};

  /// Retrieves the todo items.
  Map<List<int>, String> get items => _items;

  /// Implementation of ModuleModel.onReady():
  @override
  void onReady(ModuleContext moduleContext, Link link) {
    moduleContext.getComponentContext(_componentContext.ctrl.request());
    _componentContext.getLedger(
      _ledger.ctrl.request(),
      handleLedgerResponse('getLedger'),
    );
    _ledger.getRootPage(
      _page.ctrl.request(),
      handleLedgerResponse('getRootPage'),
    );

    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();
    _page.getSnapshot(
      snapshot.ctrl.request(),
      null,
      _pageWatcherBinding.wrap(this),
      handleLedgerResponse('Watch'),
    );

    _readItems(snapshot);
    super.onReady(moduleContext, link);
  }

  /// Implementation of ModuleModel.onStop():
  @override
  void onStop() {
    _pageWatcherBinding.close();
    _componentContext.ctrl.close();
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

  List<int> _makeKey() {
    List<int> key = <int>[];
    for (int i = 0; i < 16; i++) {
      key.add(_random.nextInt(256));
    }
    return key;
  }
}

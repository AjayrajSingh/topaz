// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fuchsia_logger/logger.dart';
import 'package:lib.widgets.dart/model.dart';

import '../ledger_helpers.dart';

/// The model for the todo list module.
class TodoListModel extends Model {
  final Random _random = Random(DateTime.now().millisecondsSinceEpoch);

  final ledger.PageWatcherBinding _pageWatcherBinding =
      ledger.PageWatcherBinding();

  final ledger.LedgerProxy _ledger = ledger.LedgerProxy();

  final ledger.PageProxy _page = ledger.PageProxy();

  /// The todo items. The source of truth is Ledger, so [_items] should never be
  /// modified directly.
  Map<List<int>, String> _items = <List<int>, String>{};

  /// Retrieves the todo items.
  Map<List<int>, String> get items => _items;

  /// Call this method to connect the model
  void connect(modular.ComponentContext componentContext) {
    _ledger.ctrl.whenClosed.then((_) => log.warning('Ledger disconnected'));
    componentContext.getLedger(_ledger.ctrl.request());

    _readInitialData();
  }

  Future<void> _readInitialData() async {
    await _ledger.getRootPage(_page.ctrl.request());

    final snapshot = ledger.PageSnapshotProxy();
    await _page.getSnapshot(
      snapshot.ctrl.request(),
      Uint8List(0),
      _pageWatcherBinding.wrap(_PageWatcher(this)),
    );
    _readItems(snapshot);
  }

  /// Call when the module should be terminated.
  Future<void> onTerminate() async {
    _pageWatcherBinding.close();
    _ledger.ctrl.close();
    _page.ctrl.close();
  }

  /// Marks the item of the given [id] as done.
  void markItemDone(List<int> id) {
    _page.delete(id);
  }

  /// Adds a new todo item with the given [content].
  void addItem(String content) {
    _page.put(_makeKey(), utf8.encode(content));
  }

  void _readItems(ledger.PageSnapshotProxy snapshot) {
    getEntriesFromSnapshot(snapshot, (Map<List<int>, String> items) {
      _items = items;
      notifyListeners();
      snapshot.ctrl.close();
    });
  }

  Uint8List _makeKey() {
    Uint8List key = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }
}

class _PageWatcher extends ledger.PageWatcher {
  final TodoListModel _model;

  _PageWatcher(this._model);

  /// Implementation of PageWatcher.onChange().
  @override
  Future<InterfaceRequest<ledger.PageSnapshot>> onChange(
    ledger.PageChange pageChange,
    ledger.ResultState resultState,
  ) async {
    if (resultState != ledger.ResultState.completed &&
        resultState != ledger.ResultState.partialStarted) {
      log.info('Unexpected result state in Ledger watcher: $resultState');
      return null;
    }
    final snapshot = ledger.PageSnapshotProxy();

    // need to call request() before _readItems so that the object
    // is bound and the subsequent reads do not fail
    final request = snapshot.ctrl.request();

    _model._readItems(snapshot);
    return request;
  }
}

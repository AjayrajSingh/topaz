// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

import 'ledger_helpers.dart';
import 'sledge.dart';
import 'transaction.dart';

/// Holds a Modification and a Completer. The [completer] completes
/// when [modification] has been ran.
class _Task {
  final Completer<bool> completer = Completer<bool>();
  final Modification modification;
  _Task(this.modification);
}

/// A queue of modifications that gets ran in transactions.
class ModificationQueue {
  Transaction _currentTransaction;
  final Queue<_Task> _tasks = ListQueue<_Task>();
  final Sledge _sledge;
  final LedgerObjectsFactory _ledgerObjectsFactory;
  final ledger.PageProxy _pageProxy;

  /// Default constructor.
  ModificationQueue(this._sledge, this._ledgerObjectsFactory, this._pageProxy);

  /// Appends [modification] to the queue of modifications.
  ///
  /// Will run [modification] once the previously queued modification
  /// has ran.
  /// Returns true if [modification] was successfully ran.
  Future<bool> queueModification(Modification modification) async {
    // The last task from the queue.
    _Task taskToAwait;
    if (_tasks.isNotEmpty) {
      taskToAwait = _tasks.last;
    }

    final task = _Task(modification);
    _tasks.add(task);

    // If some task was in the queue, await its completion.
    if (taskToAwait != null) {
      await taskToAwait.completer.future;
    }
    assert(_tasks.first == task);
    assert(_currentTransaction == null);

    // Create a transaction from [modifications], run it, and await its end.
    _currentTransaction =
        Transaction(_sledge, _pageProxy, _ledgerObjectsFactory);

    try {
      return await _currentTransaction.saveModification(modification);
    } finally {
      _currentTransaction = null;
      _tasks.removeFirst();
      task.completer.complete(true);
    }
  }

  /// The inflight transaction, if any.
  Transaction get currentTransaction => _currentTransaction;
}

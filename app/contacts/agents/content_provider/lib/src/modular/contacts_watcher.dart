// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

/// Callback to be run with the updated contact entries
typedef ProcessEntriesCallback = void Function(List<Entry> entries);

/// A [PageWatcher] implementation that looks for changes to the list of
/// contacts stored in Ledger
class ContactsWatcher extends PageWatcher {
  /// Ledger [PageWatcherBinding] to sync with ledger
  final PageWatcherBinding _pageWatcherBinding = new PageWatcherBinding();

  /// The initial snapshot
  final List<PageSnapshotProxy> _pageSnapshots = <PageSnapshotProxy>[];

  /// Function to call when there are page entry changes
  final ProcessEntriesCallback _processEntriesCallback;

  /// Creates a [ContactsWatcher] instance.
  ContactsWatcher({
    @required PageSnapshotProxy initialSnapshot,
    @required ProcessEntriesCallback processEntriesCallback,
  })  : assert(initialSnapshot != null),
        assert(processEntriesCallback != null),
        _processEntriesCallback = processEntriesCallback {
    _pageSnapshots.add(initialSnapshot);
  }

  @override
  void onChange(PageChange pageChange, ResultState resultState,
      void callback(InterfaceRequest<PageSnapshot> snapshotRequest)) {
    // Process the changed entries as they come in but only add the snapshot
    // of all changes if this is the final onChange call
    _processEntriesCallback(pageChange.changedEntries);
    if (resultState == ResultState.completed ||
        resultState == ResultState.partialCompleted) {
      PageSnapshotProxy snapshot = new PageSnapshotProxy();
      callback(snapshot.ctrl.request());
      _pageSnapshots.add(snapshot);
      log.fine('New snapshot added to list of snapshots');
    } else {
      callback(null);
    }
  }

  /// Gets the [InterfaceHandle] for this [PageWatcher] implementation.
  InterfaceHandle<PageWatcher> get pageWatcherHandle =>
      _pageWatcherBinding.wrap(this);

  /// Close the [PageWatcherBinding] that this watcher uses
  void close() {
    for (PageSnapshotProxy snapshot in _pageSnapshots) {
      snapshot.ctrl.close();
    }
    _pageWatcherBinding?.close();
  }
}

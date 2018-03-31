// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fidl/fidl.dart';
import 'package:fuchsia.fidl.ledger/ledger.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

/// Base class for our [PageWatcher] implementations.
abstract class BasePageWatcher implements PageWatcher, SyncWatcher {
  final PageWatcherBinding _pageWatcherBinding = new PageWatcherBinding();
  final SyncWatcherBinding _syncWatcherBinding = new SyncWatcherBinding();

  final List<PageSnapshotProxy> _pageSnapshots = <PageSnapshotProxy>[];

  /// The [MessageSender]s attached to the message queue of the subscriber.
  final Map<String, MessageSenderProxy> messageSenders =
      <String, MessageSenderProxy>{};

  /// Creates a new instance of [BasePageWatcher].
  BasePageWatcher({@required PageSnapshotProxy initialSnapshot})
      : assert(initialSnapshot != null) {
    _pageSnapshots.add(initialSnapshot);
  }

  /// Gets the [InterfaceHandle] for this [PageWatcher] implementation.
  InterfaceHandle<PageWatcher> get pageWatcherHandle =>
      _pageWatcherBinding.wrap(this);

  /// Gets the [InterfaceHandle] for this [SyncWatcher] implementation.
  InterfaceHandle<SyncWatcher> get syncWatcherHandle =>
      _syncWatcherBinding.wrap(this);

  /// The last known [PageSnapshot] of this conversation.
  PageSnapshot get pageSnapshot => _pageSnapshots.last;

  /// Adds a new [MessageSender] associated with the specified [token].
  void addMessageSender(String token, MessageSenderProxy messageSender) {
    messageSenders[token]?.ctrl?.close();
    messageSenders[token] = messageSender;
  }

  /// Removes a [MessageSender] associated with the specified [token].
  void removeMessageSender(String token) {
    messageSenders[token]?.ctrl?.close();
    messageSenders.remove(token);
  }

  /// Sends a [message] via all [MessageSender]s.
  void sendMessage(String message) {
    for (MessageSenderProxy sender in messageSenders.values) {
      sender.send(message);
    }
  }

  /// Closes the binding.
  void close() {
    for (MessageSenderProxy sender in messageSenders.values) {
      sender.ctrl.close();
    }
    for (PageSnapshotProxy snapshot in _pageSnapshots) {
      snapshot.ctrl.close();
    }
    _pageWatcherBinding.close();
    _syncWatcherBinding.close();
  }

  /// Not intended to be overridden by the subclasses. Subclasses must override
  /// [onPageChange] instead.
  @override
  void onChange(
    PageChange pageChange,
    ResultState resultState,
    void callback(InterfaceRequest<PageSnapshot> snapshot),
  ) {
    onPageChange(pageChange, resultState);

    InterfaceRequest<PageSnapshot> snapshotRequest;
    if (resultState == ResultState.completed ||
        resultState == ResultState.partialCompleted) {
      PageSnapshotProxy pageSnapshot = new PageSnapshotProxy();
      _pageSnapshots.add(pageSnapshot);
      snapshotRequest = pageSnapshot.ctrl.request();
      log.fine('Requesting a new snapshot');
    }
    callback(snapshotRequest);
  }

  /// Called for changes made on the Ledger page.
  ///
  /// Subclasses should override this method to handle data changes.
  void onPageChange(PageChange pageChange, ResultState resultState) => null;
}

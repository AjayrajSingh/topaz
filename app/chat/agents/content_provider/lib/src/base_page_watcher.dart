// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.ledger.services.public/ledger.fidl.dart';
import 'package:apps.modular.services.component/message_queue.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:meta/meta.dart';

/// Base class for our [PageWatcher] implementations.
abstract class BasePageWatcher implements PageWatcher, SyncWatcher {
  final PageWatcherBinding _pageWatcherBinding = new PageWatcherBinding();
  final SyncWatcherBinding _syncWatcherBinding = new SyncWatcherBinding();

  /// The [MessageSender] attached to the message queue of the subscriber.
  final MessageSenderProxy messageSender;

  /// Creates a new instance of [BasePageWatcher].
  BasePageWatcher({
    @required this.messageSender,
  }) {
    assert(messageSender != null);
  }

  /// Gets the [InterfaceHandle] for this [PageWatcher] implementation.
  InterfaceHandle<PageWatcher> get pageWatcherHandle =>
      _pageWatcherBinding.wrap(this);

  /// Gets the [InterfaceHandle] for this [SyncWatcher] implementation.
  InterfaceHandle<SyncWatcher> get syncWatcherHandle =>
      _syncWatcherBinding.wrap(this);

  /// Closes the binding.
  void close() {
    messageSender?.ctrl?.close();
    _pageWatcherBinding.close();
    _syncWatcherBinding.close();
  }
}

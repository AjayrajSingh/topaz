// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_ledger/fidl.dart';
import 'package:meta/meta.dart';

import 'base_page_watcher.dart';

/// A [PageWatcher] implementation that watches for new changes in a
/// conversation log [Page] and sends notifications to the subscriber through
/// the [MessageQueue].
class ConversationWatcher extends BasePageWatcher {
  /// The id of the conversation that this watcher is watching for.
  final List<int> conversationId;

  /// Creates a [ConversationWatcher] instance.
  ConversationWatcher({
    @required PageSnapshotProxy initialSnapshot,
    @required this.conversationId,
  })
      : assert(initialSnapshot != null),
        assert(conversationId != null),
        super(initialSnapshot: initialSnapshot);

  @override
  void onPageChange(
    PageChange pageChange,
    ResultState resultState,
  ) {
    for (Entry entry in pageChange.changedEntries) {
      // If the entry key is zero, it contains the title.
      if (entry.key.length == 1 && entry.key[0] == 0) {
        // Skip processing the title entry. This is now better handled by the
        // conversation list watcher. Keeping this if statement for backward
        // compatibility reasons.
      } else {
        _processNewEntry(entry);
      }
    }

    pageChange.deletedKeys.forEach(_processDeletedKey);
  }

  @override
  void syncStateChanged(
    SyncState downloadStatus,
    SyncState uploadStatus,
    void callback(),
  ) {
    // Don't do anything special here.
    callback();
  }

  /// Processes the provided [Entry] and sends notification to the subscriber.
  /// Refer to the `chat_content_provider.fidl` file for the message format.
  void _processNewEntry(Entry entry) {
    _notifyMessage('add', entry.key);
  }

  /// Processes the deleted key and sends notification to the subscriber.
  /// Refer to the `chat_content_provider.fidl` file for the message format.
  void _processDeletedKey(List<int> key) {
    _notifyMessage('delete', key);
  }

  void _notifyMessage(String event, List<int> messageId) {
    Map<String, Object> notification = <String, Object>{
      'event': event,
      'conversation_id': conversationId,
      'message_id': messageId,
    };

    sendMessage(json.encode(notification));
  }
}

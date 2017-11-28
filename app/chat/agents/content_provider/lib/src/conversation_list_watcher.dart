// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:lib.component.fidl/message_queue.fidl.dart';
import 'package:lib.ledger.dart/ledger.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

import 'base_page_watcher.dart';

/// A [PageWatcher] implementation that watches for changes in the
/// `conversations` [Page] which stores the list of all conversations. Whenever
/// a new [Entry] is added to this page, this [ConversationListWatcher] sends
/// notifications to the subscriber through the [MessageQueue].
class ConversationListWatcher extends BasePageWatcher {
  final Set<List<int>> _seenConversations = createLedgerIdSet();
  final Map<List<int>, Completer<Entry>> _conversationCompleters =
      createLedgerIdMap<Completer<Entry>>();
  final Completer<Null> _ready = new Completer<Null>();

  /// Creates a [ConversationListWatcher] instance.
  ConversationListWatcher({
    @required PageSnapshotProxy initialSnapshot,
  })
      : assert(initialSnapshot != null),
        super(initialSnapshot: initialSnapshot) {
    getFullEntries(initialSnapshot).then((List<Entry> entries) {
      for (Entry entry in entries) {
        _seenConversations.add(entry.key);
      }
    }).whenComplete(_ready.complete);
  }

  @override
  void onPageChange(
    PageChange pageChange,
    ResultState resultState,
  ) {
    // Process the changes independently.
    pageChange.changes.forEach(_processEntry);

    // Process the deleted conversations.
    pageChange.deletedKeys.forEach(_processDeletedKey);
  }

  @override
  void syncStateChanged(
    SyncState downloadStatus,
    SyncState uploadStatus,
    void callback(),
  ) {
    String statusString;
    switch (downloadStatus) {
      case SyncState.idle:
        statusString = 'idle';
        break;

      case SyncState.pending:
        statusString = 'pending';
        break;

      case SyncState.inProgress:
        statusString = 'in_progress';
        break;

      case SyncState.error:
        statusString = 'error';
        break;

      default:
        log.severe('Unknown downloadStatus: $downloadStatus');
        callback();
        return;
    }
    // We are only interested in download status for now.
    Map<String, String> downloadStatusNotification = <String, String>{
      'event': 'download_status',
      'status': statusString,
    };

    sendMessage(JSON.encode(downloadStatusNotification));
    callback();
  }

  /// Returns a [Future] that completes when the specified [conversationId]
  /// appears in the conversations list.
  Future<Entry> waitForConversation(List<int> conversationId) {
    if (!_conversationCompleters.containsKey(conversationId)) {
      _conversationCompleters[conversationId] = new Completer<Entry>();
    }

    return _conversationCompleters[conversationId].future;
  }

  /// Process the provided [Entry] and sends notification to the subscriber.
  /// Refer to the `chat_content_provider.fidl` file for the message format.
  Future<Null> _processEntry(Entry entry) async {
    await _ready.future;

    Map<String, Object> decoded = decodeLedgerValue(entry.value);

    Map<String, Object> notification = _seenConversations.contains(entry.key)
        ? <String, Object>{
            'event': 'conversation_title',
            'conversation_id': entry.key,
            'title': decoded['title'],
          }
        : <String, Object>{
            'event': 'new_conversation',
            'conversation_id': entry.key,
            'participants': decoded['participants'],
            'title': decoded['title'],
          };
    _seenConversations.add(entry.key);

    sendMessage(JSON.encode(notification));

    Completer<Entry> completer = _conversationCompleters[entry.key];
    if (completer != null && !completer.isCompleted) {
      completer.complete(entry);
    }
  }

  /// Process the deleted key and send notification to the clients.
  void _processDeletedKey(List<int> conversationId) {
    Map<String, Object> notification = <String, Object>{
      'event': 'delete_conversation',
      'conversation_id': conversationId,
    };

    sendMessage(JSON.encode(notification));
  }
}

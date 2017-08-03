// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:apps.ledger.services.public/ledger.fidl.dart';
import 'package:apps.modular.services.component/message_queue.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

import 'base_page_watcher.dart';
import 'ledger_utils.dart';

/// A [PageWatcher] implementation that watches for changes in the
/// `conversations` [Page] which stores the list of all conversations. Whenever
/// a new [Entry] is added to this page, this [ConversationListWatcher] sends
/// notifications to the subscriber through the [MessageQueue].
class ConversationListWatcher extends BasePageWatcher {
  final Map<List<int>, Completer<Entry>> _conversationCompleters =
      createLedgerIdMap<Completer<Entry>>();

  /// Creates a [ConversationListWatcher] instance.
  ConversationListWatcher({
    @required PageSnapshotProxy initialSnapshot,
  })
      : super(initialSnapshot: initialSnapshot) {
    assert(initialSnapshot != null);
  }

  @override
  void onPageChange(
    PageChange pageChange,
    ResultState resultState,
  ) {
    // The underlying assumption is that there will be no changes to an existing
    // conversation, and only new conversations will be added to the list of all
    // conversations. Therefore, we can safely ignore whether this onChange
    // notification is partial or complete, and just process the changes
    // independently.
    pageChange.changes.forEach(_processEntry);
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
  void _processEntry(Entry entry) {
    Map<String, dynamic> decoded = decodeLedgerValue(entry.value);

    Map<String, dynamic> newConversationNotification = <String, dynamic>{
      'event': 'new_conversation',
      'conversation_id': entry.key,
      'participants': decoded['participants'],
    };

    sendMessage(JSON.encode(newConversationNotification));

    _conversationCompleters[entry.key]?.complete(entry);
  }
}

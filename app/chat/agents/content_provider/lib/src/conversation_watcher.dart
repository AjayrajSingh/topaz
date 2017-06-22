// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:apps.ledger.services.public/ledger.fidl.dart';
import 'package:apps.modular.services.component/message_queue.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
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
    @required this.conversationId,
    @required MessageSenderProxy messageSender,
  })
      : super(messageSender: messageSender) {
    assert(this.conversationId != null);
  }

  @override
  void onChange(
    PageChange pageChange,
    ResultState resultState,
    void callback(InterfaceRequest<PageSnapshot> snapshot),
  ) {
    // The underlying assumption is that there will be no changes to an existing
    // message. Therefore, we can safely ignore whether this onChange
    // notification is partial or complete, and just process the messages
    // independently.
    pageChange.changes.forEach(_processNewEntry);
    pageChange.deletedKeys.forEach(_processDeletedKey);

    callback(null);
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
    _notifySubscribers('add', entry.key);
  }

  /// Processes the deleted key and sends notification to the subscriber.
  /// Refer to the `chat_content_provider.fidl` file for the message format.
  void _processDeletedKey(List<int> key) {
    _notifySubscribers('delete', key);
  }

  void _notifySubscribers(String event, List<int> messageId) {
    Map<String, dynamic> notification = <String, dynamic>{
      'event': event,
      'conversation_id': conversationId,
      'message_id': messageId,
    };

    messageSender.send(JSON.encode(notification));
  }
}

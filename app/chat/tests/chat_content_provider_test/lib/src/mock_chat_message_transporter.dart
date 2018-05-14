// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:topaz.app.chat.agents.content_provider._chat_content_provider_dart_library/src/chat_message_transporter.dart';
import 'package:fidl_chat_content_provider/fidl.dart';

/// A mock [ChatMessageTransporter] implementation for testing.
class MockChatMessageTransporter extends ChatMessageTransporter {
  @override
  Future<String> get currentUserEmail => new Future<String>.value('');

  @override
  Future<Null> initialize() async {}

  @override
  Future<Null> sendMessage({
    @required Conversation conversation,
    @required List<int> messageId,
    @required String type,
    @required String jsonPayload,
  }) async {}

  /// Pretends that a new message has arrived from another user and notify the
  /// client.
  Future<Null> mockReceiveMessage(
    Conversation conversation,
    Message message,
  ) async {
    if (onReceived != null) {
      await onReceived(conversation, message);
    }
  }
}

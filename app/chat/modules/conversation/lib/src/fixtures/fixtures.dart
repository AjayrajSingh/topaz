// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fixtures/fixtures.dart';
import 'package:flutter/widgets.dart';

import '../models.dart';

/// Test fixtures for chat conversation models.
class ChatConversationFixtures extends Fixtures {
  /// Gets a randomly generated chat [Message].
  Message message({DateTime time, String sender}) {
    Uint8List messageId = new Uint8List(16);
    new ByteData.view(messageId.buffer).setUint16(0, sequence('message_id'));

    return new TextMessage(
      messageId: messageId,
      time: time ?? new DateTime.now(),
      sender: sender ?? _sender(),
      text: lorem.createSentence(),
    );
  }

  /// Gets a randomly generated chat [Section].
  Section section({
    String sender,
    int numMessages,
    bool shouldDisplayDateHeader,
    bool shouldDisplayLastMessageTime,
  }) {
    sender ??= _sender();
    numMessages ??= rng.nextInt(3) + 1;

    List<Message> messages = <Message>[];
    for (int i = 0; i < numMessages; ++i) {
      messages.add(message(sender: sender));
    }

    return new Section(
      messages: messages,
      shouldDisplayDateHeader: shouldDisplayDateHeader ?? rng.nextBool(),
      shouldDisplayLastMessageTime:
          shouldDisplayLastMessageTime ?? rng.nextBool(),
    );
  }

  String _sender() =>
      rng.nextBool() ? 'me' : name().replaceAll(' ', '.').toLowerCase();

  /// Returns a [Text] widget with a randomly generated sentence in it.
  Text sentenceText() {
    return new Text(lorem.createSentence());
  }
}

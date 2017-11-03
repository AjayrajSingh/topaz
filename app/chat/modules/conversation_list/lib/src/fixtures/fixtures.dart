// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fixtures/fixtures.dart';

import '../models.dart';

/// Test fixtures for chat conversation models.
class ChatConversationFixtures extends Fixtures {
  /// Gets a randomly generated chat [Conversation].
  Conversation conversation({List<int> id, String snippet}) {
    List<int> conversationId = id;
    if (conversationId == null) {
      Uint8List idList = new Uint8List(16);
      new ByteData.view(idList.buffer)
          .setUint16(0, sequence('conversation_id'));
      conversationId = idList;
    }

    return new Conversation(
      conversationId: conversationId,
      participants: <User>[new User.fixture()],
      snippet: snippet ?? lorem.createSentence(),
    );
  }
}

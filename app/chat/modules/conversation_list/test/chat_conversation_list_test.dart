// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_conversation_list/fixtures.dart';
import 'package:chat_conversation_list/models.dart';
import 'package:chat_conversation_list/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Test to see if tapping on the new chat FAB will call the '
      'appropriate callback', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      new MaterialApp(
        home: new Material(
          child: new ChatConversationList(
            conversations: new Set<Conversation>(),
            onNewConversation: () {
              taps++;
            },
          ),
        ),
      ),
    );

    expect(taps, 0);
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
  });

  testWidgets(
      'Test to see if tapping on a conversation in the list calls the '
      'appropriate callback', (WidgetTester tester) async {
    ChatConversationFixtures fixtures = new ChatConversationFixtures();
    List<int> taps = <int>[0, 0];

    await tester.pumpWidget(
      new MaterialApp(
        home: new Material(
          child: new ChatConversationList(
            conversations: <Conversation>[
              fixtures.conversation(id: <int>[0], snippet: 'Snippet #1'),
              fixtures.conversation(id: <int>[1], snippet: 'Snippet #2'),
            ].toSet(),
            onSelectConversation: (Conversation c) =>
                taps[c.conversationId[0]]++,
          ),
        ),
      ),
    );

    expect(taps, orderedEquals(<int>[0, 0]));
    await tester.tap(find.text('Snippet #1'));
    expect(taps, orderedEquals(<int>[1, 0]));
    await tester.tap(find.text('Snippet #2'));
    expect(taps, orderedEquals(<int>[1, 1]));
  });
}

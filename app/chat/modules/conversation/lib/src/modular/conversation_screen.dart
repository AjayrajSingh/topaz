// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:topaz.app.chat.services/chat_content_provider.fidl.dart'
    as chat_fidl;

import '../widgets.dart';
import 'conversation_module_model.dart';

/// Top-level widget for the chat_conversation module.
class ChatConversationScreen extends StatelessWidget {
  /// Creates a new instance of [ChatConversationScreen].
  const ChatConversationScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(primarySwatch: Colors.purple),
      home: new Material(
        // Scaffold is used to show snack bar messages.
        child: new Scaffold(
          body: new ScopedModelDescendant<ChatConversationModuleModel>(
            builder: buildChatConversation,
          ),
        ),
      ),
    );
  }

  /// Builder used to generate the widget tree for a [ScopedModelDescendant]
  /// requireing a [ChatConversationModuleModel] parent.
  Widget buildChatConversation(
    BuildContext context,
    Widget child,
    ChatConversationModuleModel model,
  ) {
    return new ChatConversation(
      enabled: model.conversationId != null,
      sections: model.sections,
      commandMessages: model.commandMessages,
      title: model.fetchingConversation
          ? ''
          : model.participants
              ?.map(
                (chat_fidl.Participant p) => p.displayName ?? p.email,
              )
              ?.join(', '),
      onSubmitMessage: model.sendMessage,
      onTapSharePhoto: model.startGalleryModule,
      scrollController: model.scrollController,
    );
  }
}

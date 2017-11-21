// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show BASE64;

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
      home: new ScopedModelDescendant<ChatConversationModuleModel>(
        builder: buildChatConversation,
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
    // Scaffold is used to show snack bar messages.
    return new Scaffold(
      key: model.scaffoldKey,
      body: new Material(
        child: new ChatConversation(
          key: model.conversationId != null
              ? new ValueKey<String>(BASE64.encode(model.conversationId))
              : null,
          enabled: model.conversationId != null,
          sections: model.sections,
          title: model.fetchingConversation
              ? ''
              : model.title ??
                  model.participants
                      ?.map(
                        (chat_fidl.Participant p) => p.displayName ?? p.email,
                      )
                      ?.join(', '),
          onSubmitMessage: model.sendMessage,
          onSubmitTitle: model.setConversationTitle,
          onTapSharePhoto: model.startGalleryModule,
          scrollController: model.scrollController,
        ),
      ),
    );
  }
}

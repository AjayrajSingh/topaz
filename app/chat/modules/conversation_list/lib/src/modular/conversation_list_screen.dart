// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../models.dart';
import '../widgets.dart';
import 'conversation_list_module_model.dart';

/// Top-level widget for the chat_conversation_list module.
class ChatConversationListScreen extends StatefulWidget {
  /// Creates a new instance of [ChatConversationListScreen].
  ChatConversationListScreen({Key key}) : super(key: key);

  @override
  _ChatConversationListScreenState createState() =>
      new _ChatConversationListScreenState();
}

class _ChatConversationListScreenState
    extends State<ChatConversationListScreen> {
  final TextEditingController _textController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(primarySwatch: Colors.purple),
      home: new Material(
        child: new ScopedModelDescendant<ChatConversationListModuleModel>(
          builder: (
            BuildContext context,
            Widget child,
            ChatConversationListModuleModel model,
          ) {
            List<Widget> stackChildren = <Widget>[
              new ChatConversationList(
                conversations: model.conversations == null
                    ? <Conversation>[]
                    : model.conversations,
                onNewConversation: model.showNewConversationForm,
                onSelectConversation: (Conversation c) => model
                  ..setConversationId(c.conversationId)
                  ..focusConversation(),
                selectedId: model.conversationId,
                shouldDisplaySpinner: model.shouldDisplaySpinner,
              ),
            ];

            if (model.shouldShowNewConversationForm) {
              stackChildren.addAll(<Widget>[
                new GestureDetector(
                  onTapUp: (_) => model.hideNewConversationForm(),
                  child: new Container(
                    color: Colors.black.withAlpha(180),
                  ),
                ),
                _buildNewConversationForm(context, model),
              ]);
            }

            return new Stack(
              fit: StackFit.passthrough,
              children: stackChildren,
            );
          },
        ),
      ),
    );
  }

  /// Builds a new conversation form using material alert dialog.
  Widget _buildNewConversationForm(
    BuildContext context,
    ChatConversationListModuleModel model,
  ) {
    ThemeData theme = Theme.of(context);

    return new Center(
      child: new AnimatedBuilder(
        animation: _textController,
        builder: (BuildContext context, Widget child) {
          return new AlertDialog(
            title: new Text('New Chat'),
            content: new Row(
              children: <Widget>[
                new Expanded(
                  child: new TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Enter email'),
                    controller: _textController,
                    onSubmitted: (String text) => text.isNotEmpty
                        ? _handleConversationFormSubmit(model, text)
                        : null,
                  ),
                ),
                new IconButton(
                  icon: new Icon(Icons.add_circle_outline),
                  color: theme.primaryColor,
                  onPressed: _shouldEnablePlusButton(_textController.text)
                      ? _handlePlusButton
                      : null,
                ),
              ],
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text('CANCEL'),
                onPressed: model.hideNewConversationForm,
              ),
              new FlatButton(
                child: new Text('OK'),
                onPressed: _textController.text.isNotEmpty
                    ? () => _handleConversationFormSubmit(
                        model, _textController.text)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Determines whether the circled plus button should be enabled or not.
  bool _shouldEnablePlusButton(String text) =>
      text.trim().isNotEmpty && !text.trim().endsWith(',');

  /// Adds ', ' to the end of the text input and advances the cursor to the end.
  void _handlePlusButton() {
    _textController.text = _textController.text + ', ';
    _textController.selection = new TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  /// Creates a new conversation with the given participants.
  void _handleConversationFormSubmit(
    ChatConversationListModuleModel model,
    String text,
  ) {
    List<String> participants =
        text.split(',').map((String s) => s.trim()).toList();
    model.hideNewConversationForm();
    model.newConversation(participants);
    _textController.clear();
  }
}

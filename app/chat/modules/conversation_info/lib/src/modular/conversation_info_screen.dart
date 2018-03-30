// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart'
    as fidl;

import '../widgets.dart';
import 'conversation_info_module_model.dart';

/// Top-level widget for the chat_conversation_info mod.
class ConversationInfoScreen extends StatelessWidget {
  /// Creates a new instance of [ConversationInfoScreen] widget.
  const ConversationInfoScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Material(
      child: new ScopedModelDescendant<ConversationInfoModuleModel>(
        builder: (
          BuildContext context,
          Widget child,
          ConversationInfoModuleModel model,
        ) {
          return new Scaffold(
            key: model.scaffoldKey,
            body: new Column(
              children: <Widget>[
                new TitleSection(
                  initialTitle: model.title ??
                      model.participants
                          ?.map(
                            (fidl.Participant p) => p.displayName ?? p.email,
                          )
                          ?.join(', '),
                  onTitleSubmitted: model.setConversationTitle,
                ),
                new ParticipantsSection(
                  editingEnabled: model.supportsMembershipEditing,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

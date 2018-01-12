// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

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
                  initialTitle: model.title,
                  onTitleSubmitted: model.setConversationTitle,
                ),
                const ParticipantsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

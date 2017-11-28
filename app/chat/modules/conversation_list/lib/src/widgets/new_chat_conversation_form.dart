// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'constants.dart';

/// UI Widget that represents the form to create a new chat
class NewChatConversationForm extends StatelessWidget {
  /// Callback to handle the form cancel action
  final VoidCallback onFormCancel;

  /// Callback to handle the form submit action
  final NewConversationFormSubmitCallback onFormSubmit;

  /// Constructor
  const NewChatConversationForm({
    Key key,
    @required this.onFormCancel,
    @required this.onFormSubmit,
  })
      : assert(onFormCancel != null),
        assert(onFormSubmit != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<FormModel>(
      builder: (BuildContext context, Widget child, FormModel model) {
        return new AlertDialog(
          title: new Text(kNewChatFormTitle),
          content: _buildParticipantInputField(context, model),
          actions: <Widget>[
            new FlatButton(
              child: new Text(kNewChatFormCancel),
              onPressed: () {
                model.clear();
                onFormCancel?.call();
              },
            ),
            new FlatButton(
              child: new Text(kNewChatFormSubmit),
              onPressed: model.shouldEnableSubmitButton()
                  ? () => model.handleConversationFormSubmit(
                        context,
                        model.textController.text,
                        onFormSubmit,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }

  /// Build the participant input field that converts the comma separated values
  /// into chips upon submit
  Widget _buildParticipantInputField(BuildContext context, FormModel model) {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new Container(
          constraints: new BoxConstraints(maxHeight: 150.0),
          child: new SingleChildScrollView(
            reverse: true,
            child: new Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: model.participants.map((String email) {
                return new Chip(
                  label: new Text(email, overflow: TextOverflow.ellipsis),
                  onDeleted: () => model.removeParticipant(email),
                );
              }).toList(),
            ),
          ),
        ),
        new TextField(
          autofocus: true,
          focusNode: model.textFieldFocusNode,
          decoration: const InputDecoration(hintText: kNewChatFormHintText),
          controller: model.textController,
          onSubmitted: (String text) => model.handleInputSubmit(
                context,
                text,
                onFormSubmit,
              ),
        ),
      ],
    );
  }
}

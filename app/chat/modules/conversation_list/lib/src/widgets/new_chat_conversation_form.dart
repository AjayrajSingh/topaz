// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'constants.dart';

/// Callback function signature for the action to submit the new conversation
/// form
typedef void NewConversationFormSubmitCallback(List<String> participants);

/// UI Widget that represents the form to create a new chat
class NewChatConversationForm extends StatefulWidget {
  /// Callback to handle the form cancel action
  final VoidCallback onFormCancel;

  /// Callback to handle the form submit action
  final NewConversationFormSubmitCallback onFormSubmit;

  /// Constructor
  NewChatConversationForm({
    Key key,
    @required this.onFormCancel,
    @required this.onFormSubmit,
  })
      : super(key: key) {
    assert(this.onFormCancel != null);
    assert(this.onFormSubmit != null);
  }

  @override
  _NewChatConversationFormState createState() =>
      new _NewChatConversationFormState();
}

class _NewChatConversationFormState extends State<NewChatConversationForm> {
  final List<String> _participants = new List<String>();
  final TextEditingController _textController = new TextEditingController();
  final FocusNode _textFieldFocusNode = new FocusNode();

  @override
  Widget build(BuildContext context) {
    return new AnimatedBuilder(
      animation: _textController,
      builder: (BuildContext context, Widget child) {
        return new AlertDialog(
          title: new Text(kNewChatFormTitle),
          content: _buildParticipantInputField(),
          actions: <Widget>[
            new FlatButton(
              child: new Text(kNewChatFormCancel),
              onPressed: widget.onFormCancel,
            ),
            new FlatButton(
              child: new Text(kNewChatFormSubmit),
              onPressed: _shouldEnableSubmitButton(_textController.text)
                  ? () => _handleConversationFormSubmit(_textController.text)
                  : null,
            ),
          ],
        );
      },
    );
  }

  /// Build the participant input field that converts the comma separated values
  /// into chips upon submit
  Widget _buildParticipantInputField() {
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
              children: _participants.map((String email) {
                // TODO(meiyili): handle emails wider than container (SO-625)
                return new Chip(
                  label: new Text(email),
                  onDeleted: () {
                    setState(() {
                      _participants.remove(email);
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        new TextField(
          autofocus: true,
          focusNode: _textFieldFocusNode,
          decoration: const InputDecoration(hintText: kNewChatFormHintText),
          controller: _textController,
          onSubmitted: _handleInputSubmit,
        ),
      ],
    );
  }

  /// Convert a comma separated string into a set of distinct values that
  /// maintains the insertion order;
  /// empty strings are not added to the resulting set
  Set<String> _getDistinctValuesFromCSV(String text) {
    return text
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet();
  }

  /// Determines whether we should submit the list of participants
  bool _shouldSubmitForm(String text) =>
      text.trim().isEmpty && _participants.isNotEmpty;

  /// Add the new text in the input field to the list of participants;
  /// if there are multiple values delimited by commas, it will add multiple
  /// values. By default [refocus] is true which will refocus back on the
  /// text field.
  void _addNewParticipants(String text, {bool refocus = true}) {
    _participants.addAll(_getDistinctValuesFromCSV(text)
        .where((String s) => !_participants.contains(s)));
    _textController.clear();

    // refocus back into the text field so that multiple values can be typed
    if (refocus) {
      FocusScope.of(context).requestFocus(_textFieldFocusNode);
    }
  }

  /// Determines whether the submit button should be enabled or not.
  bool _shouldEnableSubmitButton(String text) {
    return _getDistinctValuesFromCSV(text).isNotEmpty ||
        _participants.isNotEmpty;
  }

  /// Creates a new conversation with the given participants.
  void _handleConversationFormSubmit(String text) {
    _addNewParticipants(text, refocus: false);
    widget.onFormSubmit(_participants);
  }

  /// Handles the text field submit action and determines whether to add the
  /// new text to the participant list or submit the form
  void _handleInputSubmit(String text) {
    if (_shouldSubmitForm(text)) {
      _handleConversationFormSubmit(text);
    } else {
      _addNewParticipants(text);
    }
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

/// Callback function signature for the action to submit the new conversation
/// form
typedef NewConversationFormSubmitCallback = void Function(
    List<String> participants);

/// The model for the new conversation form.
class FormModel extends Model {
  final List<String> _participants = <String>[];
  final FocusNode _textFieldFocusNode = new FocusNode();
  final TextEditingController _textController = new TextEditingController();

  /// Creates a new instance of [FormModel].
  FormModel() {
    // We want to notify the listeners when the text content changes.
    _textController.addListener(notifyListeners);
  }

  /// Gets the list of participants added as chips so far.
  List<String> get participants =>
      new UnmodifiableListView<String>(_participants);

  /// Gets the focus node for the text field.
  FocusNode get textFieldFocusNode => _textFieldFocusNode;

  /// Gets the controller for the text field.
  TextEditingController get textController => _textController;

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
  void addNewParticipants(
    BuildContext context,
    String text, {
    bool refocus = true,
  }) {
    _participants.addAll(_getDistinctValuesFromCSV(text)
        .where((String s) => !_participants.contains(s)));
    _textController.clear();

    // refocus back into the text field so that multiple values can be typed
    if (refocus) {
      FocusScope.of(context).requestFocus(_textFieldFocusNode);
    }

    notifyListeners();
  }

  /// Remove the specified participant.
  void removeParticipant(String email) {
    _participants.remove(email);
    notifyListeners();
  }

  /// Determines whether the submit button should be enabled or not.
  bool shouldEnableSubmitButton() {
    String text = textController.text;
    return _getDistinctValuesFromCSV(text).isNotEmpty ||
        _participants.isNotEmpty;
  }

  /// Creates a new conversation with the given participants.
  void handleConversationFormSubmit(
    BuildContext context,
    String text,
    NewConversationFormSubmitCallback onFormSubmit,
  ) {
    addNewParticipants(context, text, refocus: false);
    onFormSubmit?.call(_participants);
    clear();
  }

  /// Handles the text field submit action and determines whether to add the
  /// new text to the participant list or submit the form
  void handleInputSubmit(
    BuildContext context,
    String text,
    NewConversationFormSubmitCallback onFormSubmit,
  ) {
    if (_shouldSubmitForm(text)) {
      handleConversationFormSubmit(context, text, onFormSubmit);
    } else {
      addNewParticipants(context, text);
    }
  }

  /// Clears the data.
  void clear() {
    _participants.clear();
    _textController.clear();
  }
}

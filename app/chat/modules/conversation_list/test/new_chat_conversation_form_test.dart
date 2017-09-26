// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_conversation_list/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<String> _participants = new List<String>();

  /// Clears [_participants] and adds the contents of [participants] param to it
  void _mockSubmitFunction(List<String> participants) {
    _participants.clear();
    _participants.addAll(participants);
  }

  /// Create a NewChatConversationForm for testing; it is wrapped in a
  /// MaterialApp to handle the text in the widget
  Widget _buildTestWidget({VoidCallback onFormCancelCallback}) {
    _participants.clear();
    return new MaterialApp(
      home: new Material(
        child: new NewChatConversationForm(
          onFormCancel: onFormCancelCallback ?? () {},
          onFormSubmit: _mockSubmitFunction,
        ),
      ),
    );
  }

  /// Enters the specified [text] into the [tester]'s NewChatConversationForm
  /// widget and submits the form
  Future<Null> _submitNewConversationFormWithText(
      WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FlatButton, kNewChatFormSubmit));
  }

  /// Enters the specified [text] into the [tester]'s NewChatConversationForm's
  /// TextField and invokes the onSubmitted handler
  /// Note: assumes only one TextField widget
  void _submitFormTextFieldWithText(WidgetTester tester, String text) {
    TextField textField = tester.widget(find.byType(TextField));
    textField.onSubmitted(text);
  }

  // Test form cancel handler
  testWidgets('Tapping the cancel button should call the onFormCancel handler',
      (WidgetTester tester) async {
    bool cancelled = false;
    await tester.pumpWidget(_buildTestWidget(onFormCancelCallback: () {
      cancelled = true;
    }));

    await tester.tap(find.widgetWithText(FlatButton, kNewChatFormCancel));

    expect(cancelled, isTrue);
  });

  // Test form submit handler
  testWidgets(
      'Tapping submit when nothing has been entered, should not result in any '
      'participants and the submit button should be disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestWidget());

    Finder submitFinder = find.widgetWithText(FlatButton, kNewChatFormSubmit);
    await tester.tap(submitFinder);

    FlatButton submitButton = tester.widget(submitFinder);
    expect(submitButton.enabled, isFalse);
    expect(_participants, hasLength(0));
  });

  testWidgets(
      'Tapping submit should call the submit handler with a list containing '
      'the text', (WidgetTester tester) async {
    String text = 'hello world';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    expect(_participants, hasLength(1));
    expect(_participants[0], text);
  });

  testWidgets(
      'Tapping submit should call the submit handler with a list containing '
      'both the text in the textfield and text already in the participants '
      'list', (WidgetTester tester) async {
    String text = 'hello';
    String newText = 'world';
    await tester.pumpWidget(_buildTestWidget());

    _submitFormTextFieldWithText(tester, text);
    await _submitNewConversationFormWithText(tester, newText);

    expect(_participants, hasLength(2));
    expect(_participants, orderedEquals(<String>[text, newText]));
  });

  testWidgets(
      'Tapping submit should call the submit handler with a list containing '
      'the text in the textfield and text already in the participants list '
      'without duplicates', (WidgetTester tester) async {
    String text = 'hello, world';
    String newText = 'hello';
    await tester.pumpWidget(_buildTestWidget());

    _submitFormTextFieldWithText(tester, text);
    await _submitNewConversationFormWithText(tester, newText);

    expect(_participants, hasLength(2));
    expect(_participants, orderedEquals(<String>['hello', 'world']));
  });

  // Test text field value parse logic
  testWidgets('Submitting a single input should result in a single participant',
      (WidgetTester tester) async {
    String text = 'a';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    expect(_participants, hasLength(1));
    expect(_participants[0], text);
  });

  testWidgets(
      'Submitting n comma separated values should result in n participants',
      (WidgetTester tester) async {
    String text = 'a, b, c';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    expect(_participants, hasLength(3));
    expect(_participants, orderedEquals(<String>['a', 'b', 'c']));
  });

  testWidgets(
      'Submitting only commas and spaces should not populate the participant '
      'list and the submit button should be disabled',
      (WidgetTester tester) async {
    String text = ' ,,    ,,,, , , ';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    FlatButton submitButton =
        tester.widget(find.widgetWithText(FlatButton, kNewChatFormSubmit));
    expect(submitButton.enabled, isFalse);
    expect(_participants, hasLength(0));
  });

  testWidgets(
      'Submitting n comma separated values with some empty values and '
      'spaces should still result in n participants',
      (WidgetTester tester) async {
    String text = ',a, b,    ,,,, , c,';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    expect(_participants, hasLength(3));
    expect(_participants, orderedEquals(<String>['a', 'b', 'c']));
  });

  testWidgets(
      'Submitting comma separated values with duplicates should result '
      'in only the distinct values', (WidgetTester tester) async {
    String text = 'a, b, c, c, b';
    await tester.pumpWidget(_buildTestWidget());
    await _submitNewConversationFormWithText(tester, text);

    expect(_participants, hasLength(3));
    expect(_participants, orderedEquals(<String>['a', 'b', 'c']));
  });
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_picker/stores.dart';
import 'package:contacts_picker/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Create a NewChatConversationForm for testing; it is wrapped in a
/// MaterialApp to handle the text in the widget
Widget _buildTestWidget(ContactItem listItem) {
  return new MaterialApp(
    home: new Material(
      child: new ListView(children: <Widget>[listItem]),
    ),
  );
}

List<TextSpan> _getTextParts(WidgetTester tester) {
  ListTile listTile = tester.widget(find.byType(ListTile));
  RichText richText = listTile.title;
  return richText.text.children;
}

void main() {
  group('ContactItem', () {
    List<String> nameComponents = <String>['Alpha', 'Beta', 'Gamma', 'Epsilon'];

    group('matched on name', () {
      testWidgets(
        'should bold the first name component',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: nameComponents,
            isMatchedOnName: true,
            matchedNameIndex: 0,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'a',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[**A**][lpha Beta Gamma Epsilon]"
          expect(textParts, hasLength(2));
          expect(textParts[0].text, equals('A'));
          expect(textParts[0].style.fontWeight, equals(FontWeight.bold));
          expect(textParts[1].text, equals('lpha Beta Gamma Epsilon'));
        },
      );

      testWidgets(
        'should bold middle name component',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: nameComponents,
            isMatchedOnName: true,
            matchedNameIndex: 1,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'be',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[Alpha][** Be**][ta Gamma Epsilon]"
          expect(textParts, hasLength(3));
          expect(textParts[0].text, equals('Alpha'));
          expect(textParts[1].text, equals(' Be'));
          expect(textParts[1].style.fontWeight, equals(FontWeight.bold));
          expect(textParts[2].text, equals('ta Gamma Epsilon'));
        },
      );

      testWidgets(
        'should bold middle name component in full',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: nameComponents,
            isMatchedOnName: true,
            matchedNameIndex: 1,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'beta',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[Alpha][** Beta**][ Gamma Epsilon]"
          expect(textParts, hasLength(3));
          expect(textParts[0].text, equals('Alpha'));
          expect(textParts[1].text, equals(' Beta'));
          expect(textParts[1].style.fontWeight, equals(FontWeight.bold));
          expect(textParts[2].text, equals(' Gamma Epsilon'));
        },
      );

      testWidgets(
        'should bold the last name component',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: nameComponents,
            isMatchedOnName: true,
            matchedNameIndex: 3,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'Epsilon',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[Alpha Beta Gamma][** Epsilon**]"
          expect(textParts, hasLength(2));
          expect(textParts[0].text, equals('Alpha Beta Gamma'));
          expect(textParts[1].text, equals(' Epsilon'));
          expect(textParts[1].style.fontWeight, equals(FontWeight.bold));
        },
      );

      testWidgets(
        'should include detail if it exists',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: <String>['Alpha'],
            detail: 'alpha@example.com',
            isMatchedOnName: true,
            matchedNameIndex: 0,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'alpha',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[**Alpha**][ - alpha@example.com]"
          expect(textParts, hasLength(2));
          expect(textParts[0].text, equals('Alpha'));
          expect(textParts[1].text, equals(' - alpha@example.com'));
        },
      );

      testWidgets(
        'should not include detail if it is empty',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: <String>['Alpha'],
            isMatchedOnName: true,
            matchedNameIndex: 0,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: 'alpha',
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[**Alpha**]"
          expect(textParts, hasLength(1));
          expect(textParts[0].text, equals('Alpha'));
        },
      );
    });

    group('matched on detail', () {
      testWidgets('should not bold delimiter', (WidgetTester tester) async {
        ContactItemStore contact = new ContactItemStore(
          id: '1',
          names: <String>['Alpha'],
          detail: 'alpha@example.com',
          isMatchedOnName: false,
        );
        ContactItem testItem = new ContactItem(
          matchedPrefix: 'alpha',
          contact: contact,
        );

        await tester.pumpWidget(_buildTestWidget(testItem));
        List<TextSpan> textParts = _getTextParts(tester);

        // Using ** to denote bolded text, the resulting list item text should
        // have parts: "[Alpha][ - ][**alpha**][@example.com]"
        expect(textParts, hasLength(4));
        expect(textParts[0].text, equals('Alpha'));
        expect(textParts[1].text, equals(' - '));
        expect(textParts[2].text, equals('alpha'));
        expect(textParts[2].style.fontWeight, equals(FontWeight.bold));
        expect(textParts[3].text, equals('@example.com'));
      });

      testWidgets(
        'should not include text span for empty unbolded portion',
        (WidgetTester tester) async {
          ContactItemStore contact = new ContactItemStore(
            id: '1',
            names: <String>['Alpha'],
            detail: 'alpha@example.com',
            isMatchedOnName: false,
          );
          ContactItem testItem = new ContactItem(
            matchedPrefix: contact.detail,
            contact: contact,
          );

          await tester.pumpWidget(_buildTestWidget(testItem));
          List<TextSpan> textParts = _getTextParts(tester);

          // Using ** to denote bolded text, the resulting list item text should
          // have parts: "[Alpha][ - ][**alpha@example.com**]"
          expect(textParts, hasLength(3));
          expect(textParts[0].text, equals('Alpha'));
          expect(textParts[1].text, equals(' - '));
          expect(textParts[2].text, equals('alpha@example.com'));
          expect(textParts[2].style.fontWeight, equals(FontWeight.bold));
        },
      );
    });
  });
}

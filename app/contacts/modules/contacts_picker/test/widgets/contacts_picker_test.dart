// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:contacts_picker/stores.dart';
import 'package:contacts_picker/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidl_contacts_content_provider/fidl.dart'
    as fidl;

List<fidl.Contact> _contacts = <fidl.Contact>[
  createContact('Alpha', '1'),
  createContact('Beta', '2'),
  createContact('Gamma', '3'),
];

fidl.Contact createContact(String name, String id) => new fidl.Contact(
      contactId: id,
      sourceContactId: id,
      sourceId: 'test',
      displayName: name,
      emails: <fidl.EmailAddress>[],
      phoneNumbers: <fidl.PhoneNumber>[],
    );

Finder findByRichText(String text) {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! RichText) {
      return false;
    }

    RichText richText = widget;
    return richText.text.toPlainText() == text;
  });
}

void main() {
  // HACK: The store must be created first, before we can use the actions.
  // This line guarantees that the ContactsPickerStore is correctly created.
  contactsPickerStoreToken;

  updateContactsListAction(_contacts);

  group('ContactsPicker', () {
    testWidgets('callback should be called with the correct contact',
        (WidgetTester tester) async {
      Map<String, int> tapped = <String, int>{};
      await tester.pumpWidget(new MaterialApp(
        home: new Material(
          child: new Container(
            width: 400.0,
            height: 400.0,
            child: new ContactsPicker(
              onContactTapped: (ContactItemStore contact) {
                if (tapped.containsKey(contact.id)) {
                  tapped[contact.id]++;
                } else {
                  tapped[contact.id] = 1;
                }
              },
            ),
          ),
        ),
      ));

      final MapEquality<String, int> mapEquality =
          const MapEquality<String, int>();

      expect(
        mapEquality.equals(tapped, <String, int>{}),
        isTrue,
      );

      await tester.tap(findByRichText('Alpha'));
      expect(
        mapEquality.equals(tapped, <String, int>{'1': 1}),
        isTrue,
      );

      await tester.tap(findByRichText('Beta'));
      expect(
        mapEquality.equals(tapped, <String, int>{'1': 1, '2': 1}),
        isTrue,
      );

      await tester.tap(findByRichText('Gamma'));
      expect(
        mapEquality.equals(tapped, <String, int>{'1': 1, '2': 1, '3': 1}),
        isTrue,
      );
    });
  });
}

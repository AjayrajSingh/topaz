// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contact_list/models.dart';
import 'package:test/test.dart';

void main() {
  group('ContactListModel', () {
    test('should set contact list if contactList param is not null', () {
      List<ContactListItem> contactList = <ContactListItem>[
        new ContactListItem(id: 'id', displayName: 'displayName'),
      ];
      ContactListModel model = new ContactListModel(contactList: contactList);

      expect(model.contactList, equals(contactList));
    });

    test('should set contact list to empty list if contactList param is null',
        () {
      ContactListModel model = new ContactListModel();

      expect(model.contactList, hasLength(0));
    });
  });
}

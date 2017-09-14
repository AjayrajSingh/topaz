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

    test('should properly mark the first items in each letter category', () {
      List<ContactListItem> contactList = <ContactListItem>[
        new ContactListItem(id: 'id', displayName: 'Danielle Kim'),
        new ContactListItem(id: 'id', displayName: 'Danielle Stawski'),
        new ContactListItem(id: 'id', displayName: 'Eric Chowdhury'),
        new ContactListItem(id: 'id', displayName: 'Eve Mann'),
        new ContactListItem(id: 'id', displayName: 'E. T. Atkins'),
      ];
      ContactListModel model = new ContactListModel(contactList: contactList);

      expect(model.firstItems.contains(contactList[0]), equals(true));
      expect(model.firstItems.contains(contactList[1]), equals(false));
      expect(model.firstItems.contains(contactList[2]), equals(true));
      expect(model.firstItems.contains(contactList[3]), equals(false));
      expect(model.firstItems.contains(contactList[4]), equals(false));
    });
  });
}

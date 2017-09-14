// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:lib.widgets/model.dart';

import 'contact_list_item.dart';

/// The [ContactListModel] is the data store for the Contact list module as well
/// as the methods for updating and manipulating this data.
/// It has purposely been kept separate from all FIDL interface interactions so
/// that it can be easily tested.
class ContactListModel extends Model {
  List<ContactListItem> _contactList;
  Set<ContactListItem> _firstItems;

  /// Creates an instance of the [ContactListModel].
  ContactListModel({List<ContactListItem> contactList}) {
    _contactList = contactList ?? <ContactListItem>[];
    _firstItems = _createFirstItemSet(_contactList);
  }

  /// Stored list of contacts
  List<ContactListItem> get contactList =>
      new UnmodifiableListView<ContactListItem>(_contactList);
  set contactList(List<ContactListItem> contactList) {
    _contactList = contactList;
    _firstItems = _createFirstItemSet(contactList);
    notifyListeners();
  }

  /// Store of [ContactListItem]s that are the first in their category
  Set<ContactListItem> get firstItems =>
      new UnmodifiableSetView<ContactListItem>(_firstItems);

  /// Go through list and set the flag for all items that are the first in its
  /// category.
  ///
  /// Return a set containing all of the items that are the first in each
  /// category.
  Set<ContactListItem> _createFirstItemSet(List<ContactListItem> contactList) {
    Set<ContactListItem> firstItems = new Set<ContactListItem>();
    if (contactList != null) {
      for (int i = 0; i < contactList.length; i++) {
        if (i == 0 ||
            contactList[i].firstLetter != contactList[i - 1].firstLetter) {
          firstItems.add(contactList[i]);
        }
      }
    }
    return firstItems;
  }
}

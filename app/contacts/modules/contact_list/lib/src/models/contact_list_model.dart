// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:lib.widgets/model.dart';

import 'contact_list_item.dart';

/// The action to search the contacts store with a given prefix
typedef void SearchContactsAction(String prefix);

/// The action to clear the search results
typedef void ClearSearchResultsAction();

/// The [ContactListModel] is the data store for the Contact list module as well
/// as the methods for updating and manipulating this data.
/// It has purposely been kept separate from all FIDL interface interactions so
/// that it can be easily tested.
class ContactListModel extends Model {
  List<ContactListItem> _searchResults = <ContactListItem>[];
  List<ContactListItem> _contacts;
  Set<ContactListItem> _firstItems;

  /// Creates an instance of the [ContactListModel].
  ContactListModel({List<ContactListItem> contactList}) {
    _contacts = contactList ?? <ContactListItem>[];
    _firstItems = _createFirstItemSet(_contacts);
  }

  /// Stored list of contacts
  List<ContactListItem> get contacts =>
      new UnmodifiableListView<ContactListItem>(_contacts);
  set contacts(List<ContactListItem> contacts) {
    _contacts = contacts;
    _firstItems = _createFirstItemSet(contacts);
    notifyListeners();
  }

  /// Stored list of search results
  List<ContactListItem> get searchResults =>
      new UnmodifiableListView<ContactListItem>(_searchResults);
  set searchResults(List<ContactListItem> searchResults) {
    _searchResults = searchResults;
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
  Set<ContactListItem> _createFirstItemSet(List<ContactListItem> contacts) {
    Set<ContactListItem> firstItems = new Set<ContactListItem>();
    if (contacts != null) {
      for (int i = 0; i < contacts.length; i++) {
        if (i == 0 || contacts[i].firstLetter != contacts[i - 1].firstLetter) {
          firstItems.add(contacts[i]);
        }
      }
    }
    return firstItems;
  }
}

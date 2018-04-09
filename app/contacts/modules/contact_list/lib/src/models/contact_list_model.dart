// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:lib.widgets/model.dart';

import 'contact_item.dart';

/// The [ContactListModel] is the data store for the Contact list module as well
/// as the methods for updating and manipulating this data.
/// It has purposely been kept separate from all FIDL interface interactions so
/// that it can be easily tested.
class ContactListModel extends Model {
  List<ContactItem> _searchResults = <ContactItem>[];
  List<ContactItem> _contacts;
  Set<ContactItem> _firstItems;
  bool _error;

  /// Creates an instance of the [ContactListModel].
  ContactListModel({List<ContactItem> contactList}) {
    _contacts = contactList ?? <ContactItem>[];
    _firstItems = _createFirstItemSet(_contacts);
  }

  /// Stored list of contacts
  List<ContactItem> get contacts =>
      new UnmodifiableListView<ContactItem>(_contacts);
  set contacts(List<ContactItem> contacts) {
    _contacts = contacts;
    _firstItems = _createFirstItemSet(contacts);
    notifyListeners();
  }

  /// Stored list of search results
  List<ContactItem> get searchResults =>
      new UnmodifiableListView<ContactItem>(_searchResults);
  set searchResults(List<ContactItem> searchResults) {
    _searchResults = searchResults;
    notifyListeners();
  }

  /// Store of [ContactItem]s that are the first in their category
  Set<ContactItem> get firstItems =>
      new UnmodifiableSetView<ContactItem>(_firstItems);

  /// Whether or not there was an error
  bool get error => _error;
  set error(bool value) {
    _error = value;
    notifyListeners();
  }

  /// Go through list and set the flag for all items that are the first in its
  /// category.
  ///
  /// Return a set containing all of the items that are the first in each
  /// category.
  Set<ContactItem> _createFirstItemSet(List<ContactItem> contacts) {
    Set<ContactItem> firstItems = new Set<ContactItem>();
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

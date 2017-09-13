// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';

import 'contact_list_item.dart';

/// The [ContactListModel] is the data store for the Contact list module as well
/// as the methods for updating and manipulating this data.
/// It has purposely been kept separate from all FIDL interface interactions so
/// that it can be easily tested.
class ContactListModel extends Model {
  List<ContactListItem> _contactList;

  /// Creates an instance of the [ContactListModel].
  ContactListModel({List<ContactListItem> contactList}) {
    _contactList = contactList ?? <ContactListItem>[];
  }

  /// Stored list of contacts
  List<ContactListItem> get contactList => _contactList;
  set contactList(List<ContactListItem> contactList) {
    _contactList = contactList;
    notifyListeners();
  }
}

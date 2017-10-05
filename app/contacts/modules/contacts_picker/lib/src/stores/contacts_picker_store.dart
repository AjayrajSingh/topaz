// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter_flux/flutter_flux.dart';

import 'contact_list_item.dart';

/// Holds the data in the contacts store
class ContactsPickerStore extends Store {
  List<ContactListItem> _contacts = <ContactListItem>[];

  /// Constructor
  ContactsPickerStore() {
    triggerOnAction(updateContactsListAction, (List<ContactListItem> contacts) {
      _contacts = contacts;
    });
  }

  /// An immutable list of contacts
  List<ContactListItem> get contacts =>
      new UnmodifiableListView<ContactListItem>(_contacts);
}

/// Token to be used to subscribe to the [ContactsPickerStore]'s data
final StoreToken contactsPickerStoreToken =
    new StoreToken(new ContactsPickerStore());

/// Action to update the list of contacts in the [ContactsPickerStore]
Action<List<ContactListItem>> updateContactsListAction =
    new Action<List<ContactListItem>>();

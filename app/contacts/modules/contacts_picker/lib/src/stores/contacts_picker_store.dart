// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter_flux/flutter_flux.dart';
import 'package:lib.logging/logging.dart';

import 'contact_item_store.dart';

/// Holds the data in the contacts store
class ContactsPickerStore extends Store {
  List<ContactItemStore> _contacts = <ContactItemStore>[];
  String _prefix = '';

  /// Constructor
  ContactsPickerStore() {
    triggerOnAction(
      updateContactsListAction,

      // ignore: strong_mode_uses_dynamic_as_bottom
      (List<ContactItemStore> contacts) {
        _contacts = contacts;
        log.fine('ContactsPickerStore: contacts updated');
      },
    );

    triggerOnAction(
      updatePrefixAction,

      // ignore: strong_mode_uses_dynamic_as_bottom
      (String prefix) {
        _prefix = prefix;
        log.fine('ContactsPickerStore: prefix updated to $prefix');
      },
    );
  }

  /// An immutable list of contacts
  List<ContactItemStore> get contacts =>
      new UnmodifiableListView<ContactItemStore>(_contacts);

  /// The prefix that the search results reflect
  String get prefix => _prefix;
}

/// Token to be used to subscribe to the [ContactsPickerStore]'s data
final StoreToken contactsPickerStoreToken =
    new StoreToken(new ContactsPickerStore());

/// Action to update the list of contacts in the [ContactsPickerStore]
Action<List<ContactItemStore>> updateContactsListAction =
    new Action<List<ContactItemStore>>();

/// Action to update the prefix in [ContactsPickerStore]
Action<String> updatePrefixAction = new Action<String>();

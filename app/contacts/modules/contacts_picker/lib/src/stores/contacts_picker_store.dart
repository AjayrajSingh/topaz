// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter_flux/flutter_flux.dart';
import 'package:fidl_contacts_content_provider/fidl.dart'
    as fidl;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/com.fuchsia.contact.dart';

import 'contact_item_store.dart';

/// Holds the data in the contacts store
class ContactsPickerStore extends Store {
  List<ContactItemStore> _contacts = <ContactItemStore>[];
  FilterEntityData _filter = new FilterEntityData();

  /// Constructor
  ContactsPickerStore() {
    triggerOnAction(
      updateContactsListAction,

      // ignore: strong_mode_uses_dynamic_as_bottom
      (List<fidl.Contact> contacts) {
        _contacts = contacts.map(_transformContact).toList();
        log.fine('ContactsPickerStore: contacts updated');
      },
    );

    triggerOnAction(
      updateFilterAction,

      // ignore: strong_mode_uses_dynamic_as_bottom
      (FilterEntityData filter) {
        _filter = filter;
        log.fine(
            'ContactsPickerStore: filter updated, prefix = ${filter.prefix}');
      },
    );
  }

  /// An immutable list of contacts
  List<ContactItemStore> get contacts =>
      new UnmodifiableListView<ContactItemStore>(_contacts);

  /// The prefix that the search results reflect
  String get prefix => _filter.prefix;

  /// Transform a FIDL Contact object into a ContactItemStore
  ContactItemStore _transformContact(fidl.Contact c) {
    // TODO(meiyili): change how emails and phone numbers are stored and update
    // to handle the "custom" detail type as well
    String detail = '';
    if (_filter.detailType == DetailType.email && c.emails.isNotEmpty) {
      detail = c.emails[0].value;
    } else if (_filter.detailType == DetailType.phoneNumber &&
        c.phoneNumbers.isNotEmpty) {
      detail = c.phoneNumbers[0].value;
    }

    List<String> nameComponents = <String>[c.displayName];
    bool isMatchedOnName = false;
    int matchedNameIndex = -1;
    for (int i = 0; i < nameComponents.length; i++) {
      if (nameComponents[i].toLowerCase().startsWith(prefix)) {
        isMatchedOnName = true;
        matchedNameIndex = i;
      }
    }

    return new ContactItemStore(
      id: c.contactId,
      names: nameComponents,
      detail: detail,
      photoUrl: c.photoUrl,
      isMatchedOnName: isMatchedOnName,
      matchedNameIndex: matchedNameIndex,
    );
  }
}

/// Token to be used to subscribe to the [ContactsPickerStore]'s data
final StoreToken contactsPickerStoreToken =
    new StoreToken(new ContactsPickerStore());

/// Action to update the list of contacts in the [ContactsPickerStore]
Action<List<fidl.Contact>> updateContactsListAction =
    new Action<List<fidl.Contact>>();

/// Action to update the prefix in [ContactsPickerStore]
Action<FilterEntityData> updateFilterAction = new Action<FilterEntityData>();

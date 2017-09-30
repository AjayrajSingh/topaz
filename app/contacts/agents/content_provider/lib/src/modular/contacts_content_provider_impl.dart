// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.fidl.dart/bindings.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart';

import '../store/contacts_store.dart';

/// Initial stub implementation
class ContactsContentProviderImpl extends ContactsContentProvider {
  final ContactsStore<Contact> _contactsStore = new ContactsStore<Contact>();
  final List<ContactsContentProviderBinding> _bindings =
      <ContactsContentProviderBinding>[];

  /// Runs necessary methods to initialize the contacts content provider
  void initialize() {
    // Make call to retrieve the list of contacts
    // TODO(meiyili) replace with a call to the necessary service agents and
    // ledger and create a fixture with the stub contact generation code
    List<Contact> contacts = <Contact>[
      _createStubContact('1', 'Ahonui', 'Armadillo'),
      _createStubContact('2', 'Badia', 'Blue-Whale'),
      _createStubContact('3', 'Candida', 'Capybara'),
      _createStubContact('4', 'Daniel', 'Dewey'),
      _createStubContact('5', 'Ada', 'Lovelace'),
      _createStubContact('6', 'Alan', 'Turing'),
      _createStubContact('7', 'Barbara', 'McClintock'),
      _createStubContact('8', 'Benjamin', 'Banneker'),
      _createStubContact('9', 'Clara', 'Schumann'),
      _createStubContact('10', 'Claude', 'Debussy'),
      _createStubContact('11', 'Daphne', 'du Maurier'),
      _createStubContact('12', 'Dmitri', 'Mendeleev'),
    ];

    // Add all of the contacts to the contacts store
    for (Contact contact in contacts) {
      List<String> searchableValues = <String>[
        contact.displayName.trim().toLowerCase(),
        contact.familyName.trim().toLowerCase(),
        contact.emails[0].value.trim().toLowerCase(),
      ];
      _contactsStore.addContact(
        contact.googleContactId,
        contact.displayName,
        searchableValues,
        contact,
      );
    }
  }

  /// Stub implementation of getContactList
  @override
  Future<Null> getContactList(String prefix,
      void callback(Status status, List<Contact> contacts)) async {
    List<Contact> contactsList;
    if (prefix == null || prefix == '') {
      contactsList = _contactsStore.getAllContacts();
    } else {
      Map<String, Set<Contact>> contacts = _contactsStore.search(prefix);

      // Merge into set first to avoid duplicates
      contactsList =
          contacts.values.expand((Set<Contact> s) => s).toSet().toList();
    }
    callback(Status.ok, contactsList);
    return;
  }

  /// Stub implementation of getContact
  @override
  Future<Null> getContact(
      String id, void callback(Status status, Contact contact)) async {
    callback(Status.ok, _contactsStore.getContact(id));
    return;
  }

  /// Add request to the list of binding objects.
  void addBinding(InterfaceRequest<ContactsContentProvider> request) {
    _bindings.add(new ContactsContentProviderBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    for (ContactsContentProviderBinding binding in _bindings) {
      binding.close();
    }
    _bindings.clear();
  }

  /// Temporary for stub implementations
  /// TODO(meiyili) remove when implementing the actual methods
  Contact _createStubContact(String id, String givenName, String familyName) {
    return new Contact()
      ..googleContactId = id
      ..displayName = '$givenName $familyName'
      ..givenName = givenName
      ..middleName = givenName.substring(0, 1)
      ..familyName = familyName
      ..emails = <EmailAddress>[
        new EmailAddress()
          ..label = 'primary'
          ..value = '$familyName$givenName@example.com'.toLowerCase()
      ]
      ..phoneNumbers = <PhoneNumber>[
        new PhoneNumber()
          ..label = 'mobile'
          ..value = '12345678910'
      ]
      ..photoUrl = '';
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:apps.modules.contacts.services/contacts_content_provider.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Initial stub implementation
class ContactsContentProviderImpl extends ContactsContentProvider {
  final List<ContactsContentProviderBinding> _bindings =
      <ContactsContentProviderBinding>[];

  /// Stub implementation of getContactList
  @override
  Future<Null> getContactList(String prefix,
      void callback(Status status, List<Contact> contacts)) async {
    List<Contact> stubList = <Contact>[
      _createStubContact('Arnold', 'Armadillo'),
      _createStubContact('Christina', 'Capybara'),
      _createStubContact('Daniel', 'Dugong'),
    ];

    callback(Status.ok, stubList);
    return;
  }

  /// Stub implementation of getContact
  @override
  Future<Null> getContact(
      String email, void callback(Status status, Contact contact)) async {
    // Added to simulate a non-existent email, this is not a reserved email
    if (email == 'doesnotexist@example.com') {
      callback(Status.ok, null);
      return;
    }

    callback(Status.ok, _createStubContact('Arnold', 'Armadillo'));
    return;
  }

  /// Add request to the list of binding objects.
  void addBinding(InterfaceRequest<ContactsContentProvider> request) {
    _bindings.add(new ContactsContentProviderBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    _bindings.forEach(
      (ContactsContentProviderBinding binding) => binding.close(),
    );
    _bindings.clear();
  }

  /// Temporary for stub implementations
  /// TODO(meiyili) remove when implementing the actual methods
  Contact _createStubContact(String givenName, String familyName) {
    return new Contact()
      ..googleContactId = 'id'
      ..displayName = '$givenName $familyName'
      ..givenName = givenName
      ..middleName = givenName.substring(0, 1)
      ..familyName = familyName
      ..emails = <EmailAddress>[
        new EmailAddress()
          ..label = 'primary'
          ..value = '$givenName$familyName@google.com'
      ]
      ..phoneNumbers = <PhoneNumber>[
        new PhoneNumber()
          ..label = 'mobile'
          ..value = '12345678910'
      ]
      ..photoUrl = 'photoUrl.jpg';
  }
}

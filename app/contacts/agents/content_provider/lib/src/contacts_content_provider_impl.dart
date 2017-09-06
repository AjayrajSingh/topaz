// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:apps.modules.contacts.services/contacts_content_provider.fidl.dart';

/// Initial stub implementation
class ContactsContentProviderImpl extends ContactsContentProvider {
  @override
  Future<Null> getContactsList(
      String prefix, void callback(List<Contact> contacts)) async {
    List<Contact> stubList = <Contact>[
      _createStubContact('Arnold', 'Armadillo'),
      _createStubContact('Christina', 'Capybara'),
      _createStubContact('Daniel', 'Dugong'),
    ];

    callback(stubList);
    return;
  }

  @override
  Future<Null> getContact(String email, void callback(Contact contact)) async {
    if (email == 'doesnotexist@google.com') {
      callback(null);
      return;
    }

    callback(_createStubContact('Arnold', 'Armadillo'));
    return;
  }

  /// Temporary
  /// TODO(meiyili) remove when implementing the actual methods
  Contact _createStubContact(String givenName, String familyName) {
    return new Contact()
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

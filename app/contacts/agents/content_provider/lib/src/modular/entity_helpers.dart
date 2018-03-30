// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:entity_schemas/entities.dart' as entities;
import 'package:fuchsia.fidl.contacts_content_provider/contacts_content_provider.dart'
    as fidl;

/// Converts a [fidl.Contact] into a [entities.Contact] entity
entities.Contact getEntityFromContact(fidl.Contact contact) {
  return new entities.Contact(
    id: contact.contactId,
    displayName: contact.displayName,
    givenName: contact.givenName,
    familyName: contact.familyName,
    middleName: contact.middleName,
    photoUrl: contact.photoUrl,
    emailAddresses: contact.emails.map(getEntityFromEmail).toList(),
    phoneNumbers: contact.phoneNumbers.map(getEntityFromPhoneNumber).toList(),
  );
}

/// Converts a [fidl.EmailAddress] into a [entities.EmailAddress] entity
entities.EmailAddress getEntityFromEmail(fidl.EmailAddress email) {
  return new entities.EmailAddress(value: email.value, label: email.label);
}

/// Converts a [fidl.PhoneNumber] into a [entities.PhoneNumber] entity
entities.PhoneNumber getEntityFromPhoneNumber(fidl.PhoneNumber number) {
  return new entities.PhoneNumber(number: number.value, label: number.label);
}

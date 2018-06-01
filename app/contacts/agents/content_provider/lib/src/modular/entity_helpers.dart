// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_contacts_content_provider/fidl.dart' as fidl;
import 'package:lib.schemas.dart/com.fuchsia.contact.dart' as entities;

/// Converts a [fidl.Contact] into a [entities.ContactEntityData] entity
entities.ContactEntityData getEntityFromContact(fidl.Contact contact) {
  return new entities.ContactEntityData(
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

/// Converts a [fidl.EmailAddress] into a [entities.EmailEntityData] entity
entities.EmailEntityData getEntityFromEmail(fidl.EmailAddress email) {
  return new entities.EmailEntityData(
    value: email.value,
    label: email.label,
  );
}

/// Converts a [fidl.PhoneNumber] into a [entities.PhoneNumberEntityData] entity
entities.PhoneNumberEntityData getEntityFromPhoneNumber(
    fidl.PhoneNumber number) {
  return new entities.PhoneNumberEntityData(
    number: number.value,
    label: number.label,
  );
}

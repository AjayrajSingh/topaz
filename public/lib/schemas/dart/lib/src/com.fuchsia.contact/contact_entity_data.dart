// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'email_entity_data.dart';
import 'phone_number_entity_data.dart';

/// The data for a Contact entity
class ContactEntityData {
  /// The contact id
  final String id;

  /// Full name of contact, usually givenName + familyName
  final String displayName;

  /// First name for contact
  final String givenName;

  /// Middle name for contact
  final String middleName;

  /// Last name for contact
  final String familyName;

  /// Email addresses associated with contact
  final List<EmailEntityData> emailAddresses;

  /// Phone numbers associated with contact
  final List<PhoneNumberEntityData> phoneNumbers;

  /// URL for main contact profile photo;
  final String photoUrl;

  /// Constructor
  ContactEntityData({
    @required this.id,
    @required this.displayName,
    this.givenName,
    this.familyName,
    this.middleName,
    this.photoUrl,
    List<EmailEntityData> emailAddresses,
    List<PhoneNumberEntityData> phoneNumbers,
  })  : assert(id != null && id.isNotEmpty),
        assert(displayName != null && displayName.isNotEmpty),
        emailAddresses = new List<EmailEntityData>.unmodifiable(
            emailAddresses ?? <EmailEntityData>[]),
        phoneNumbers = new List<PhoneNumberEntityData>.unmodifiable(
            phoneNumbers ?? <PhoneNumberEntityData>[]);

  /// The primary email is the first entry in the list of emails
  /// Returns null if there is no email for contact
  EmailEntityData get primaryEmail {
    if (emailAddresses.isEmpty) {
      return null;
    } else {
      return emailAddresses[0];
    }
  }

  /// The primary phone number is the first entry in the list of phone numbers
  /// Returns null if there is no phone number for contact
  PhoneNumberEntityData get primaryPhoneNumber {
    if (phoneNumbers.isEmpty) {
      return null;
    } else {
      return phoneNumbers[0];
    }
  }
}

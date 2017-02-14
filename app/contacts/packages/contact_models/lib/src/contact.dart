// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'entry_types.dart';

/// A Model representing a contact entry
class Contact {
  /// Unique Identifier for given contact
  final String id;

  /// Full name of contact, usually givenName + familyName
  final String displayName;

  /// First name for contact
  final String givenName;

  /// Last name for contact
  final String familyName;

  /// Physical addresses associated with contact
  final List<Address> addresses;

  /// Email addresses associated with contact
  final List<EmailAddress> emailAddresses;

  /// Phone numbers associated with contact
  final List<PhoneNumber> phoneNumbers;

  /// Social Networks associated with contact
  final List<SocialNetwork> socialNetworks;

  /// URL for background image
  final String backgroundImageUrl;

  /// URL for main contact profile photo;
  final String photoUrl;

  /// Constructor
  Contact({
    this.id,
    this.displayName,
    this.givenName,
    this.familyName,
    this.backgroundImageUrl,
    this.photoUrl,
    List<Address> addresses,
    List<EmailAddress> emailAddresses,
    List<PhoneNumber> phoneNumbers,
    List<SocialNetwork> socialNetworks,
  })
      : addresses =
            new List<Address>.unmodifiable(addresses ?? <Address>[]),
        emailAddresses = new List<EmailAddress>.unmodifiable(emailAddresses ?? <EmailAddress>[]),
        phoneNumbers =
            new List<PhoneNumber>.unmodifiable(phoneNumbers ?? <PhoneNumber>[]),
        socialNetworks = new List<SocialNetwork>.unmodifiable(
            socialNetworks ?? <SocialNetwork>[]);

  /// The primary address is the first address in the list of addresses
  /// Returns null if there is no address for contact
  Address get primaryAddress {
    if (addresses.isEmpty) {
      return null;
    } else {
      return addresses[0];
    }
  }

  /// The primary email is the first entry in the list of emails
  /// Returns null if there is no email for contact
  EmailAddress get primaryEmail {
    if (emailAddresses.isEmpty) {
      return null;
    } else {
      return emailAddresses[0];
    }
  }

  /// The primary phone number is the first entry in the list of phone numbers
  /// Returns null if there is no phone number for contact
  PhoneNumber get primaryPhoneNumber {
    if (phoneNumbers.isEmpty) {
      return null;
    } else {
      return phoneNumbers[0];
    }
  }

  /// Gets the region preview (city, region) for a given contact
  /// Uses the primary address to generate the preview
  /// Returns null if there is no primary address of if there is no city or
  /// region for the primary address.
  String get regionPreview {
    if (primaryAddress == null ||
        (primaryAddress.city == null && primaryAddress.region == null)) {
      return null;
    }
    if (primaryAddress.city != null && primaryAddress.region != null) {
      return '${primaryAddress.city}, ${primaryAddress.region}';
    } else {
      return primaryAddress.city ?? primaryAddress.region;
    }
  }
}

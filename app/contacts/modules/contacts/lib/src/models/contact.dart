// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:widgets_meta/widgets_meta.dart';

import 'entry_types.dart';
import 'fixtures.dart';

/// A Model representing a contact entry
@Generator(ContactModelFixtures, 'contact')
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
      : addresses = new List<Address>.unmodifiable(addresses ?? <Address>[]),
        emailAddresses = new List<EmailAddress>.unmodifiable(
            emailAddresses ?? <EmailAddress>[]),
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

  /// Helper function to encode a Contact model into a json string
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{};

    json['id'] = id;
    json['displayName'] = displayName;
    json['givenName'] = givenName;
    json['familyName'] = familyName;
    json['backgroundImageUrl'] = backgroundImageUrl;
    json['photoUrl'] = photoUrl;
    json['id'] = id;
    json['addresses'] = addresses.map((Address a) => a.toJson()).toList();
    json['emailAddresses'] =
        emailAddresses.map((EmailAddress e) => e.toJson()).toList();
    json['phoneNumbers'] =
        phoneNumbers.map((PhoneNumber n) => n.toJson()).toList();
    json['socialNetworks'] =
        socialNetworks.map((SocialNetwork n) => n.toJson()).toList();

    return json;
  }
}

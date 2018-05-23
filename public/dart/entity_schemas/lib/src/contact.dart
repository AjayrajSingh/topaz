// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

import 'email.dart';
import 'phone_number.dart';

const String _kType = 'Contact';

/// The Entity Schema for a Contact
///
/// WIP for the first pass of work with Entities
class Contact {
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
  final List<EmailAddress> emailAddresses;

  /// Phone numbers associated with contact
  final List<PhoneNumber> phoneNumbers;

  /// URL for main contact profile photo;
  final String photoUrl;

  /// Constructor
  Contact({
    @required this.id,
    @required this.displayName,
    this.givenName,
    this.familyName,
    this.middleName,
    this.photoUrl,
    List<EmailAddress> emailAddresses,
    List<PhoneNumber> phoneNumbers,
  })  : assert(id != null && id.isNotEmpty),
        assert(displayName != null && displayName.isNotEmpty),
        emailAddresses = new List<EmailAddress>.unmodifiable(
            emailAddresses ?? <EmailAddress>[]),
        phoneNumbers =
            new List<PhoneNumber>.unmodifiable(phoneNumbers ?? <PhoneNumber>[]);

  /// Instantiate a contact from a json string
  factory Contact.fromJson(String encodedJson) {
    try {
      Map<String, dynamic> decodedJson = json.decode(encodedJson);
      return new Contact(
        id: decodedJson['id'],
        displayName: decodedJson['displayName'],
        givenName: decodedJson['givenName'] ?? '',
        familyName: decodedJson['familyName'] ?? '',
        middleName: decodedJson['middleName'] ?? '',
        photoUrl: decodedJson['photoUrl'] ?? '',
        emailAddresses: decodedJson['emailAddresses']
            .map((String emailJson) => new EmailAddress.fromJson(emailJson))
            .toList(),
        phoneNumbers: decodedJson['phoneNumbers']
            .map((String numberJson) => new PhoneNumber.fromJson(numberJson))
            .toList(),
      );
    } on Exception catch (e) {
      // since this is just a first pass, not really going to do too much
      // additional validation here but would like to know if this ever does
      // error out
      log.warning('$_kType entity error when decoding from json string: $json'
          '\nerror: $e');
      rethrow;
    }
  }

  /// Instantiate a contact from the data string provided by the entity
  /// framework
  factory Contact.fromData(String data) {
    return new Contact.fromJson(data);
  }

  /// Get the type of this entity
  static String getType() => _kType;

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

  @override
  String toString() => toJson();

  /// Helper function to encode a contact entity into a json string
  String toJson() {
    Map<String, Object> data = <String, Object>{};

    data['id'] = id;
    data['displayName'] = displayName;
    data['givenName'] = givenName;
    data['middleName'] = middleName;
    data['familyName'] = familyName;
    data['photoUrl'] = photoUrl;
    data['emailAddresses'] =
        emailAddresses.map((EmailAddress e) => e.toJson()).toList();
    data['phoneNumbers'] =
        phoneNumbers.map((PhoneNumber n) => n.toJson()).toList();

    return json.encode(data);
  }

  /// Encode the entity into the data string to be passed around by the entity
  /// framework
  String toData() {
    return toJson();
  }
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:lib.logging/logging.dart';

import '../../com.fuchsia.contact.dart';
import '../entity_codec.dart';

const String _kType = 'com.fuchsia.contact';

/// The [EntityCodec] that translates the [ContactEntityData]
class ContactEntityCodec extends EntityCodec<ContactEntityData> {
  /// Constructor
  ContactEntityCodec()
      : super(
          type: _kType,
          encode: _encode,
          decode: _decode,
        );
}

/// Encodes [ContactEntityData] into a [String]
String _encode(ContactEntityData contact) {
  Map<String, Object> data = <String, Object>{};
  EmailEntityCodec emailCodec = new EmailEntityCodec();
  PhoneNumberEntityCodec phoneCodec = new PhoneNumberEntityCodec();

  data['id'] = contact.id;
  data['displayName'] = contact.displayName;
  data['givenName'] = contact.givenName;
  data['middleName'] = contact.middleName;
  data['familyName'] = contact.familyName;
  data['photoUrl'] = contact.photoUrl;
  data['emailAddresses'] =
      contact.emailAddresses.map(emailCodec.encode).toList();
  data['phoneNumbers'] = contact.phoneNumbers.map(phoneCodec.encode).toList();

  return json.encode(data);
}

/// Decodes [String] into a structured [ContactEntityData]
ContactEntityData _decode(String data) {
  assert(data != null);
  assert(data.isNotEmpty);

  try {
    Map<String, dynamic> decodedJson = json.decode(data);
    return new ContactEntityData(
      id: decodedJson['id'],
      displayName: decodedJson['displayName'],
      givenName: decodedJson['givenName'] ?? '',
      familyName: decodedJson['familyName'] ?? '',
      middleName: decodedJson['middleName'] ?? '',
      photoUrl: decodedJson['photoUrl'] ?? '',
      emailAddresses: decodedJson['emailAddresses']
          .map((String emailJson) => new EmailEntityCodec()..decode(emailJson))
          .toList(),
      phoneNumbers: decodedJson['phoneNumbers']
          .map((String numberJson) =>
              new PhoneNumberEntityCodec()..decode(numberJson))
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

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../../lib/src/models.dart';
import '../../lib/src/models/fixtures.dart';

void main() {
  group('EmailAddress', () {
    test('toJson()', () {
      ContactModelFixtures fixtures = new ContactModelFixtures();
      Contact contact = fixtures.contact();
      Map<String, dynamic> json = contact.toJson();
      expect(json['id'], contact.id);
      expect(json['displayName'], contact.displayName);
      expect(json['givenName'], contact.givenName);
      expect(json['familyName'], contact.familyName);
      expect(json['backgroundImageUrl'], contact.backgroundImageUrl);
      expect(json['photoUrl'], contact.photoUrl);
      expect(json['addresses'][0]['city'], contact.addresses[0].city);
      expect(json['emailAddresses'][0]['value'],
          contact.emailAddresses[0].value);
      expect(json['phoneNumbers'][0]['number'], contact.phoneNumbers[0].number);
      expect(json['socialNetworks'][0]['type'],
          contact.socialNetworks[0].type.index);
      expect(json['socialNetworks'][0]['account'],
          contact.socialNetworks[0].account);
    });
  });
}

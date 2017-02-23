// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';
import 'package:uuid/uuid.dart';

import 'contact.dart';
import 'entry_types.dart';

class ContactModelFixtures extends Fixtures {
  static final String _uuidContact =
      Fixtures.uuid.v5(Uuid.NAMESPACE_URL, namespace('contacts'));

  /// Generate a contact
  Contact contact() {
    return new Contact(
      id: _uuidContact,
      displayName: 'Coco Yang',
      givenName: 'Coco',
      familyName: 'Yang',
      backgroundImageUrl: 'backgroundImage',
      photoUrl: 'photo',
      addresses: <Address>[
        new Address(
          city: 'bark city',
        ),
      ],
      emailAddresses: <EmailAddress>[
        new EmailAddress(
          value: 'coco@puppy.cute',
        ),
      ],
      phoneNumbers: <PhoneNumber>[
        new PhoneNumber(
          number: '1231234',
        ),
      ],
      socialNetworks: <SocialNetwork>[
        new SocialNetwork(
          type: SocialNetworkType.facebook,
          account: 'coco',
        ),
      ],
    );
  }
}

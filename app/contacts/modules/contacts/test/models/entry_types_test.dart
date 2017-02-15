// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../../lib/src/models.dart';

void main() {
  group('EmailAddress', () {
    test('toString()', () {
      EmailAddress email = new EmailAddress(
        label: 'Personal',
        value: 'coco@puppy.cute',
      );
      expect(email.toString(), 'coco@puppy.cute');
    });
  });

  group('Address', () {
    test('toString()', () {
      Address addressEntry = new Address(
        street: '1842 N Shoreline Blvd',
        city: 'Mountain View',
        region: 'California',
        postalCode: '94043',
        country: 'United States of America',
        countryCode: 'US',
      );
      expect(
          addressEntry.toString(),
          '1842 N Shoreline Blvd, '
          'Mountain View, California, 94043, United States of America, US');
    });
  });

  group('SocialNetwork', () {
    test('toString()', () {
      SocialNetwork socialNetworkEntry = new SocialNetwork(
        type: SocialNetworkType.twitter,
        account: 'google',
      );
      expect(socialNetworkEntry.toString(), 'google');
    });
  });

  group('Contact', () {
    group('primaryAddress', () {
      test('Should return null if contact contains no addresses', () {
        Contact contact = new Contact();
        expect(contact.primaryAddress, null);
      });
      test('Should return first address if contact contains addresses', () {
        Contact contact = new Contact(
          addresses: <Address>[
            new Address(
              label: 'Work',
              city: 'Mountain View',
            ),
            new Address(
              label: 'Home',
              city: 'San Francisco',
            ),
          ],
        );
        expect(contact.primaryAddress, contact.addresses[0]);
      });
    });
    group('primaryEmail', () {
      test('Should return null if contact contains no email addresses', () {
        Contact contact = new Contact();
        expect(contact.primaryEmail, null);
      });
      test('Should return first address if contact contains addresses', () {
        Contact contact = new Contact(
          emailAddresses: <EmailAddress>[
            new EmailAddress(
              label: 'Work',
              value: 'coco@work',
            ),
            new EmailAddress(
              label: 'Home',
              value: 'coco@home',
            ),
          ],
        );
        expect(contact.primaryEmail, contact.emailAddresses[0]);
      });
    });
    group('primaryPhoneNumber', () {
      test('Should return null if contact contains no phone numbers', () {
        Contact contact = new Contact();
        expect(contact.primaryPhoneNumber, null);
      });
      test('Should return first phone number if contact contains phone numbers',
          () {
        Contact contact = new Contact(
          phoneNumbers: <PhoneNumber>[
            new PhoneNumber(
              label: 'Work',
              number: '13371337',
            ),
            new PhoneNumber(
              label: 'Home',
              number: '101010101',
            ),
          ],
        );
        expect(contact.primaryPhoneNumber, contact.phoneNumbers[0]);
      });
    });
    group('regionPreview', () {
      test('Should return null if contact has no primary address', () {
        Contact contact = new Contact();
        expect(contact.regionPreview, null);
      });
      test(
          'Should return null if contact has primary address but no city nor region is given',
          () {
        Contact contact = new Contact(
          addresses: <Address>[
            new Address(
              country: 'USA',
              label: 'Work',
            )
          ],
        );
        expect(contact.regionPreview, null);
      });
      test(
          'Should return city if contact has primary address with a city and no region',
          () {
        Contact contact = new Contact(
          addresses: <Address>[
            new Address(
              city: 'Mountain View',
              country: 'USA',
              label: 'Work',
            )
          ],
        );
        expect(contact.regionPreview, 'Mountain View');
      });
      test(
          'Should return region if contact has primary address with a region and no city',
          () {
        Contact contact = new Contact(
          addresses: <Address>[
            new Address(
              region: 'CA',
              country: 'USA',
              label: 'Work',
            )
          ],
        );
        expect(contact.regionPreview, 'CA');
      });
      test(
          'Should return city, region if contact has primary address with a region and city',
          () {
        Contact contact = new Contact(
          addresses: <Address>[
            new Address(
              city: 'Mountain View',
              region: 'CA',
              country: 'USA',
              label: 'Work',
            )
          ],
        );
        expect(contact.regionPreview, 'Mountain View, CA');
      });
    });
  });
}

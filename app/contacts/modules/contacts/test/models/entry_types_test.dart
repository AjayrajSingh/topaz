// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts/src/models.dart';
import 'package:test/test.dart';

void main() {
  group('EmailAddress', () {
    test('toString()', () {
      EmailAddress email = new EmailAddress(
        label: 'Personal',
        value: 'coco@puppy.cute',
      );
      expect(email.toString(), 'coco@puppy.cute');
    });
    test('toJson()', () {
      EmailAddress email = new EmailAddress(
        label: 'Personal',
        value: 'coco@puppy.cute',
      );
      Map<String, dynamic> json = email.toJson();
      expect(json['label'], email.label);
      expect(json['value'], email.value);
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
    test('toJson()', () {
      Address addressEntry = new Address(
        label: 'work',
        street: '1842 N Shoreline Blvd',
        city: 'Mountain View',
        region: 'California',
        postalCode: '94043',
        country: 'United States of America',
        countryCode: 'US',
      );
      Map<String, dynamic> json = addressEntry.toJson();
      expect(json['label'], addressEntry.label);
      expect(json['street'], addressEntry.street);
      expect(json['city'], addressEntry.city);
      expect(json['region'], addressEntry.region);
      expect(json['postalCode'], addressEntry.postalCode);
      expect(json['country'], addressEntry.country);
      expect(json['countryCode'], addressEntry.countryCode);
    });
  });

  group('PhoneNumber', () {
    test('toString()', () {
      PhoneNumber phoneNumber = new PhoneNumber(
        number: '1231234',
        label: 'work',
      );
      expect(
          phoneNumber.toString(), '${phoneNumber.label} ${phoneNumber.number}');
    });
    test('toJson()', () {
      PhoneNumber phoneNumber = new PhoneNumber(
        number: '1231234',
        label: 'work',
      );
      Map<String, dynamic> json = phoneNumber.toJson();
      expect(json['number'], phoneNumber.number);
      expect(json['label'], phoneNumber.label);
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
    test('toJson()', () {
      SocialNetwork socialNetworkEntry = new SocialNetwork(
        type: SocialNetworkType.twitter,
        account: 'google',
      );
      Map<String, dynamic> json = socialNetworkEntry.toJson();
      expect(json['type'], 2);
      expect(json['account'], 'google');
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

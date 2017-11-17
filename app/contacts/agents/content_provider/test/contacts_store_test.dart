// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_content_provider/store.dart';
import 'package:test/test.dart';

void main() {
  group('ContactsStore', () {
    group('addContact', () {
      group('validation', () {
        ContactsStore<String> store;

        setUp(() {
          store = new ContactsStore<String>();
        });

        tearDown(() {
          store = null;
        });

        test('should throw if id is null', () {
          expect(() {
            store.addContact(null, 'displayName', <String>['email'], 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if id is empty string', () {
          expect(() {
            store.addContact('', 'displayName', <String>['email'], 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if displayName is null', () {
          expect(() {
            store.addContact('id', null, <String>['email'], 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if displayName is empty string', () {
          expect(() {
            store.addContact('id', '', <String>['email'], 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if searchableValues is null', () {
          expect(() {
            store.addContact('id', 'displayName', null, 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if searchableValues is empty', () {
          expect(() {
            store.addContact('id', 'displayName', <String>[], 'contact');
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if contact is null', () {
          expect(() {
            store.addContact('id', 'displayName', <String>['email'], null);
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });
      });

      test('should be able to add a contact', () {
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        _MockContact contact = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          email: 'mr_armadillo@example.com',
        );
        store.addContact(
          contact.id,
          contact.displayName,
          <String>[contact.email],
          contact,
        );

        expect(store.getContact(contact.id), equals(contact));
      });

      test('should be able to add contacts with the same displayName', () {
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        String displayName = 'Armadillo';
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: displayName,
          email: 'mr_armadillo@example.com',
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: displayName,
          email: 'the_other_armadillo@example.com',
        );

        store
          ..addContact(
            contact1.id,
            contact1.displayName,
            <String>[contact1.email],
            contact1,
          )
          ..addContact(
            contact2.id,
            contact2.displayName,
            <String>[contact2.email],
            contact2,
          );

        expect(store.getContact(contact1.id), equals(contact1));
        expect(store.getContact(contact2.id), equals(contact2));
      });

      test(
          'should throw argument error '
          'if adding contact with duplicate id', () {
        expect(() {
          String id = 'contact1';
          new ContactsStore<String>()
            ..addContact(id, 'contact1', <String>['contact1'], 'contact1')
            ..addContact(id, 'contact2', <String>['contact2'], 'contact2');
        }, throwsA(const isInstanceOf<ArgumentError>()));
      });

      test('should update the contact if updateIfExists is true', () {
        String id = 'contact1';
        ContactsStore<String> store = new ContactsStore<String>()
          ..addContact(id, 'contact1', <String>['contact1'], 'contact1');
        expect(store.getContact(id), equals('contact1'));

        store.addContact(
          id,
          'contact2',
          <String>['contact2'],
          'contact2',
          updateIfExists: true,
        );
        expect(store.getContact(id), equals('contact2'));
      });
    });

    group('getAllContacts', () {
      test('should return a list of all contacts', () {
        List<_MockContact> contacts = _createContactList();
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        for (_MockContact c in contacts) {
          store.addContact(c.id, c.displayName, <String>[c.email], c);
        }

        List<_MockContact> result = store.getAllContacts();
        expect(result, hasLength(contacts.length));
        for (_MockContact c in contacts) {
          expect(result, contains(c));
        }
      });

      test('should return an empty list if there aren\'t any contacts', () {
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        expect(store.getAllContacts(), isEmpty);
      });
    });

    group('getContact', () {
      ContactsStore<_MockContact> store;

      setUp(() async {
        store = new ContactsStore<_MockContact>();
        for (_MockContact c in _createContactList()) {
          store.addContact(c.id, c.displayName, <String>[c.email], c);
        }
      });

      tearDown(() async {
        store = null;
      });

      test('should return the contact if it exists', () {
        _MockContact orca = new _MockContact(
          id: 'contact123',
          displayName: 'orca',
          email: 'not_actually_a_whale@example.com',
        );
        store.addContact(orca.id, orca.displayName, <String>[orca.email], orca);

        _MockContact result = store.getContact(orca.id);
        expect(result, equals(orca));
      });

      test('should return null if there aren\'t any contacts', () {
        ContactsStore<_MockContact> emptyStore =
            new ContactsStore<_MockContact>();
        expect(emptyStore.getContact('someId'), isNull);
      });

      test('should return null if the contact doesn\'t exist', () {
        expect(store.getContact('notAnExistingId'), isNull);
      });
    });

    group('search', () {
      test('should return contacts with displayName and email matching prefix',
          () {
        List<_MockContact> contacts = _createContactList();
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        for (_MockContact c in contacts) {
          List<String> searchableValues = <String>[c.displayName, c.email];
          store.addContact(c.id, c.displayName, searchableValues, c);
        }

        Map<String, Set<_MockContact>> result = store.search('la');
        expect(result, hasLength(3));
        expect(result, contains('latte lover'));
        expect(result, contains('largest_rodent@example.com'));
        expect(result, contains('lady_of_the_sea@example.com'));
      });

      test('should return all searchable values if prefix is an empty string',
          () {
        List<_MockContact> contacts = _createContactList();
        ContactsStore<_MockContact> store = new ContactsStore<_MockContact>();
        for (_MockContact c in contacts) {
          List<String> searchableValues = <String>[c.displayName, c.email];
          store.addContact(c.id, c.displayName, searchableValues, c);
        }

        Map<String, Set<_MockContact>> result = store.search('');
        expect(result, hasLength(10));
        for (_MockContact c in contacts) {
          expect(result, contains(c.displayName));
          expect(result, contains(c.email));
        }
      });
    });

    group('containsContact', () {
      ContactsStore<_MockContact> store;
      _MockContact c;

      setUp(() {
        store = new ContactsStore<_MockContact>();
        c = new _MockContact(id: 'id123', displayName: 'name', email: 'email');
        store.addContact(c.id, c.displayName, <String>[c.email], c);
      });

      tearDown(() {
        store = null;
      });

      test('should return true if contact is in store', () {
        expect(store.containsContact(c.id), isTrue);
      });

      test('should return false if contact is not in store', () {
        expect(store.containsContact('does not exist'), isFalse);
      });
    });
  });
}

List<_MockContact> _createContactList() {
  return <_MockContact>[
    new _MockContact(
      id: 'contact1',
      displayName: 'Armadillo',
      email: 'mr_armadillo@example.com',
    ),
    new _MockContact(
      id: 'contact2',
      displayName: 'Blue Whale',
      email: 'the_true_blue@example.com',
    ),
    new _MockContact(
      id: 'contact3',
      displayName: 'Capybara',
      email: 'largest_rodent@example.com',
    ),
    new _MockContact(
      id: 'contact4',
      displayName: 'Dewey',
      email: 'lady_of_the_sea@example.com',
    ),
    new _MockContact(
        id: 'contact5',
        displayName: 'latte lover',
        email: 'LatteLover99@example.com')
  ];
}

class _MockContact {
  final String id;
  final String displayName;
  final String email;

  _MockContact({
    this.id,
    this.displayName,
    this.email,
  });
}

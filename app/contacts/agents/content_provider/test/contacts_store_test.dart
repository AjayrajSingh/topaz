// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_content_provider/store.dart';
import 'package:test/test.dart';

class _MockContact {
  final String id;
  final String displayName;
  final List<String> tags;

  _MockContact({
    this.id,
    this.displayName,
    this.tags,
  });
}

String getId(_MockContact c) => c?.id;

String getDisplayName(_MockContact c) => c?.displayName;

List<String> getSearchableValues(_MockContact c) =>
    (<String>[c.displayName]..addAll(c.tags));

ContactsStore<_MockContact> _createStore() {
  return new ContactsStore<_MockContact>(
    getId: getId,
    getDisplayName: getDisplayName,
    getSearchableValues: getSearchableValues,
  );
}

List<_MockContact> _createContactList() {
  return <_MockContact>[
    new _MockContact(
      id: 'contact1',
      displayName: 'Armadillo',
      tags: <String>['mr_armadillo@example.com'],
    ),
    new _MockContact(
      id: 'contact2',
      displayName: 'Blue Whale',
      tags: <String>['the_true_blue@example.com'],
    ),
    new _MockContact(
      id: 'contact3',
      displayName: 'Capybara',
      tags: <String>['largest_rodent@example.com'],
    ),
    new _MockContact(
      id: 'contact4',
      displayName: 'Dewey',
      tags: <String>['lady_of_the_sea@example.com'],
    ),
    new _MockContact(
      id: 'contact5',
      displayName: 'latte lover',
      tags: <String>['LatteLover99@example.com'],
    ),
  ];
}

void main() {
  group('ContactsStore', () {
    group('addContact', () {
      group('validation', () {
        ContactsStore<_MockContact> store;

        setUp(() {
          store = _createStore();
        });

        tearDown(() {
          store = null;
        });

        test('should throw if id is null', () {
          expect(() {
            store.addContact(new _MockContact(
              displayName: 'displayName',
              tags: <String>['tag'],
            ));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if id is empty string', () {
          expect(() {
            store.addContact(new _MockContact(
              id: '',
              displayName: 'displayName',
              tags: <String>['tag'],
            ));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if displayName is null', () {
          expect(() {
            store.addContact(new _MockContact(
              id: 'id',
              tags: <String>['tag'],
            ));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if displayName is empty string', () {
          expect(() {
            store.addContact(new _MockContact(
              id: 'id',
              displayName: '',
              tags: <String>['tag'],
            ));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if searchableValues is null', () {
          expect(() {
            new ContactsStore<_MockContact>(
              getId: getId,
              getDisplayName: getDisplayName,
              getSearchableValues: (_) => null,
            )..addContact(new _MockContact(id: 'id', displayName: 'd'));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if searchableValues is empty', () {
          expect(() {
            new ContactsStore<_MockContact>(
              getId: getId,
              getDisplayName: getDisplayName,
              getSearchableValues: (_) => <String>[],
            )..addContact(new _MockContact(id: 'id', displayName: 'd'));
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });

        test('should throw if contact is null', () {
          expect(() {
            store.addContact(null);
          }, throwsA(const isInstanceOf<ArgumentError>()));
        });
      });

      test('should be able to add a contact', () {
        ContactsStore<_MockContact> store = _createStore();
        _MockContact contact = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['mr_armadillo@example.com'],
        );
        store.addContact(contact);

        expect(store.getContact(contact.id), equals(contact));
      });

      test('should be able to add contacts with the same displayName', () {
        ContactsStore<_MockContact> store = _createStore();
        String displayName = 'Armadillo';
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: displayName,
          tags: <String>['mr_armadillo@example.com'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: displayName,
          tags: <String>['the_other_armadillo@example.com'],
        );

        store..addContact(contact1)..addContact(contact2);

        expect(store.getContact(contact1.id), equals(contact1));
        expect(store.getContact(contact2.id), equals(contact2));
      });

      test(
          'should throw argument error '
          'if adding contact with duplicate id', () {
        expect(() {
          String id = 'contact1';
          _MockContact contact1 = new _MockContact(
            id: id,
            displayName: 'Mr. Armadillo',
            tags: <String>['mr_armadillo@example.com'],
          );
          _MockContact contact2 = new _MockContact(
            id: id,
            displayName: 'Mr. Other Armadillo',
            tags: <String>['the_other_armadillo@example.com'],
          );

          _createStore()..addContact(contact1)..addContact(contact2);
        }, throwsA(const isInstanceOf<ArgumentError>()));
      });

      test('should update the contact if updateIfExists is true', () {
        String id = '1';
        _MockContact contact = new _MockContact(
          id: id,
          displayName: 'Mr. Armadillo',
          tags: <String>['mr_armadillo@example.com'],
        );
        _MockContact updatedContact = new _MockContact(
          id: id,
          displayName: 'Mr. Other Armadillo',
          tags: <String>['the_other_armadillo@example.com'],
        );
        ContactsStore<_MockContact> store = _createStore()..addContact(contact);
        expect(store.getContact(id), equals(contact));

        store.addContact(updatedContact, updateIfExists: true);
        expect(store.getContact(id), equals(updatedContact));
      });
    });

    group('removeContact', () {
      test('should remove the contact from the contact map', () {
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['armadillo@example.com'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: 'Capybara',
          tags: <String>['capybara@example.com'],
        );
        ContactsStore<_MockContact> store = _createStore()
          ..addContact(contact1)
          ..addContact(contact2);
        expect(store.containsContact(contact1.id), equals(true));
        expect(store.containsContact(contact2.id), equals(true));

        store.removeContact(contact1.id);

        expect(store.containsContact(contact1.id), equals(false));
        expect(store.containsContact(contact2.id), equals(true));
      });

      test('should remove the contact\'s display name', () {
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['armadillo@example.com'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: 'Capybara',
          tags: <String>['capybara@example.com'],
        );
        ContactsStore<_MockContact> store = _createStore()
          ..addContact(contact1)
          ..addContact(contact2);
        expect(
          store.search(contact1.displayName),
          contains(contact1.displayName),
        );
        expect(
          store.search(contact2.displayName),
          contains(contact2.displayName),
        );

        store.removeContact(contact1.id);

        expect(
          store.search(contact1.displayName),
          isEmpty,
        );
        expect(
          store.search(contact2.displayName),
          contains(contact2.displayName),
        );
      });

      test('should remove the contact\'s searchable values', () {
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['armadillo@example.com'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: 'Capybara',
          tags: <String>['capybara@example.com'],
        );
        ContactsStore<_MockContact> store = _createStore()
          ..addContact(contact1)
          ..addContact(contact2);

        List<String> c1Values = getSearchableValues(contact1);
        List<String> c2Values = getSearchableValues(contact2);
        for (String s in <String>[]..addAll(c1Values)..addAll(c2Values)) {
          expect(store.search(s), contains(s));
        }

        store.removeContact(contact1.id);

        for (String s in c1Values) {
          expect(store.search(s), isEmpty);
        }
        for (String s in c2Values) {
          expect(store.search(s), contains(s));
        }
      });

      test('should not remove other contacts with the same display name', () {
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['armadillo@example.com'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: 'Armadillo',
          tags: <String>['other_armadillo@example.com'],
        );
        ContactsStore<_MockContact> store = _createStore()
          ..addContact(contact1)
          ..addContact(contact2);

        Map<String, Set<_MockContact>> searchResult = store.search('Armadillo');
        expect(searchResult['Armadillo'], hasLength(2));
        expect(searchResult['Armadillo'], contains(contact1));
        expect(searchResult['Armadillo'], contains(contact2));

        store.removeContact(contact1.id);

        searchResult = store.search('Armadillo');
        expect(searchResult['Armadillo'], hasLength(1));
        expect(searchResult['Armadillo'], contains(contact2));
      });

      test('should not remove other contacts with the same searchable value',
          () {
        _MockContact contact1 = new _MockContact(
          id: 'contact1',
          displayName: 'Armadillo',
          tags: <String>['armadillo@example.com', 'test'],
        );
        _MockContact contact2 = new _MockContact(
          id: 'contact2',
          displayName: 'Capybara',
          tags: <String>['capybara@example.com', 'test'],
        );
        ContactsStore<_MockContact> store = _createStore()
          ..addContact(contact1)
          ..addContact(contact2);

        Map<String, Set<_MockContact>> searchResult = store.search('test');
        expect(searchResult['test'], hasLength(2));
        expect(searchResult['test'], contains(contact1));
        expect(searchResult['test'], contains(contact2));

        store.removeContact(contact1.id);

        searchResult = store.search('test');
        expect(searchResult['test'], hasLength(1));
        expect(searchResult['test'], contains(contact2));
      });
    });

    group('getAllContacts', () {
      test('should return a list of all contacts', () {
        List<_MockContact> contacts = _createContactList();
        ContactsStore<_MockContact> store = _createStore();

        // ignore: prefer_foreach
        for (_MockContact c in contacts) {
          store.addContact(c);
        }

        List<_MockContact> result = store.getAllContacts();
        expect(result, hasLength(contacts.length));
        for (_MockContact c in contacts) {
          expect(result, contains(c));
        }
      });

      test('should return an empty list if there aren\'t any contacts', () {
        ContactsStore<_MockContact> store = _createStore();
        expect(store.getAllContacts(), isEmpty);
      });
    });

    group('getContact', () {
      ContactsStore<_MockContact> store;

      setUp(() async {
        store = _createStore();

        // ignore: prefer_foreach
        for (_MockContact c in _createContactList()) {
          store.addContact(c);
        }
      });

      tearDown(() async {
        store = null;
      });

      test('should return the contact if it exists', () {
        _MockContact orca = new _MockContact(
          id: 'contact123',
          displayName: 'orca',
          tags: <String>['not_actually_a_whale@example.com'],
        );
        store.addContact(orca);

        _MockContact result = store.getContact(orca.id);
        expect(result, equals(orca));
      });

      test('should return null if there aren\'t any contacts', () {
        ContactsStore<_MockContact> emptyStore = _createStore();
        expect(emptyStore.getContact('someId'), isNull);
      });

      test('should return null if the contact doesn\'t exist', () {
        expect(store.getContact('notAnExistingId'), isNull);
      });
    });

    group('search', () {
      test('should return contacts with displayName and tag matching prefix',
          () {
        List<_MockContact> contacts = _createContactList();
        ContactsStore<_MockContact> store = _createStore();

        // ignore: prefer_foreach
        for (_MockContact c in contacts) {
          store.addContact(c);
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
        ContactsStore<_MockContact> store = _createStore();

        // ignore: prefer_foreach
        for (_MockContact c in contacts) {
          store.addContact(c);
        }

        Map<String, Set<_MockContact>> result = store.search('');
        expect(result, hasLength(10));
        for (_MockContact c in contacts) {
          expect(result, contains(c.displayName));

          List<String> searchableValues = getSearchableValues(c);
          for (String s in searchableValues) {
            expect(result, contains(s));
          }
        }
      });

      test('should return empty map if store is empty', () {
        ContactsStore<_MockContact> emptyStore = _createStore();
        expect(emptyStore.search('something'), isEmpty);
      });
    });

    group('containsContact', () {
      ContactsStore<_MockContact> store;
      _MockContact c;

      setUp(() {
        store = _createStore();
        c = new _MockContact(
          id: 'id123',
          displayName: 'name',
          tags: <String>['email'],
        );
        store.addContact(c);
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

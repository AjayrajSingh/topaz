// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_content_provider/store.dart';
import 'package:fidl_fuchsia_contacts_contentprovider/fidl.dart' as fidl;
import 'package:test/test.dart';

List<fidl.Contact> _createContactList() {
  return <fidl.Contact>[
    const fidl.Contact(
      contactId: 'contact1',
      sourceContactId: '1',
      sourceId: 'test',
      displayName: 'Armadillo',
      emails: const <fidl.EmailAddress>[
        const fidl.EmailAddress(value: 'mr_armadillo@example.com')
      ],
      phoneNumbers: const <fidl.PhoneNumber>[],
    ),
    const fidl.Contact(
      contactId: 'contact2',
      sourceContactId: '2',
      sourceId: 'test',
      displayName: 'Blue Whale',
      emails: const <fidl.EmailAddress>[
        const fidl.EmailAddress(value: 'the_true_blue@example.com')
      ],
      phoneNumbers: const <fidl.PhoneNumber>[],
    ),
    const fidl.Contact(
      contactId: 'contact3',
      sourceContactId: '3',
      sourceId: 'test',
      displayName: 'Capybara',
      emails: const <fidl.EmailAddress>[
        const fidl.EmailAddress(value: 'largest_rodent@example.com')
      ],
      phoneNumbers: const <fidl.PhoneNumber>[],
    ),
    const fidl.Contact(
      contactId: 'contact4',
      sourceContactId: '4',
      sourceId: 'test',
      displayName: 'Dewey',
      emails: const <fidl.EmailAddress>[
        const fidl.EmailAddress(value: 'lady_of_the_sea@example.com')
      ],
      phoneNumbers: const <fidl.PhoneNumber>[],
    ),
    const fidl.Contact(
      contactId: 'contact5',
      sourceContactId: '5',
      sourceId: 'test',
      displayName: 'latte lover',
      emails: const <fidl.EmailAddress>[
        const fidl.EmailAddress(value: 'LatteLover99@example.com')
      ],
      phoneNumbers: const <fidl.PhoneNumber>[],
    ),
  ];
}

List<String> _getSearchableValues(fidl.Contact contact) {
  List<String> searchableValues = <String>[];
  if (contact != null) {
    // TODO: add back ability to search on parts of the users names SO-1018
    searchableValues = <String>[
      contact.displayName.trim(),
      contact.displayName.trim().toLowerCase(),
    ];

    // Allow contact to be searchable on all of their email addresses
    for (fidl.EmailAddress e in contact.emails) {
      if (e != null && e.value.trim().isNotEmpty) {
        searchableValues.add(e.value.trim());
      }
    }
  }

  return searchableValues;
}

void main() {
  group('ContactsStore', () {
    group('addContact', () {
      group('validation', () {
        ContactsStore store;

        setUp(() {
          store = new ContactsStore();
        });

        tearDown(() {
          store = null;
        });

        test('should throw if id is empty string', () {
          expect(() {
            store.addContact(const fidl.Contact(
              contactId: '',
              sourceContactId: '1',
              sourceId: 'test',
              displayName: 'Armadillo',
              emails: const <fidl.EmailAddress>[
                const fidl.EmailAddress(value: 'mr_armadillo@example.com')
              ],
              phoneNumbers: const <fidl.PhoneNumber>[],
            ));
          }, throwsA(const TypeMatcher<ArgumentError>()));
        });

        test('should throw if displayName is empty string', () {
          expect(() {
            store.addContact(const fidl.Contact(
              contactId: 'contact1',
              sourceContactId: '1',
              sourceId: 'test',
              displayName: '',
              emails: const <fidl.EmailAddress>[
                const fidl.EmailAddress(value: 'mr_armadillo@example.com')
              ],
              phoneNumbers: const <fidl.PhoneNumber>[],
            ));
          }, throwsA(const TypeMatcher<ArgumentError>()));
        });

        test('should throw if searchableValues is empty', () {
          expect(() {
            store.addContact(const fidl.Contact(
              contactId: 'contact1',
              sourceContactId: '1',
              sourceId: 'test',
              displayName: '   ',
              emails: const <fidl.EmailAddress>[],
              phoneNumbers: const <fidl.PhoneNumber>[],
            ));
          }, throwsA(const TypeMatcher<ArgumentError>()));
        });

        test('should throw if contact is null', () {
          expect(() {
            store.addContact(null);
          }, throwsA(const TypeMatcher<ArgumentError>()));
        });
      });

      test('should be able to add a contact', () {
        ContactsStore store = new ContactsStore();
        fidl.Contact contact = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        store.addContact(contact);

        expect(store.getContact(contact.contactId), equals(contact));
      });

      test('should be able to add contacts with the same displayName', () {
        ContactsStore store = new ContactsStore();
        String displayName = 'Armadillo';
        fidl.Contact contact1 = new fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: displayName,
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = new fidl.Contact(
          contactId: 'contact2',
          sourceContactId: '2',
          sourceId: 'test',
          displayName: displayName,
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'the_other_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );

        store..addContact(contact1)..addContact(contact2);

        expect(store.getContact(contact1.contactId), equals(contact1));
        expect(store.getContact(contact2.contactId), equals(contact2));
      });

      test(
          'should throw argument error '
          'if adding contact with duplicate id', () {
        expect(() {
          String id = 'contact1';
          fidl.Contact contact1 = new fidl.Contact(
            contactId: id,
            sourceContactId: '1',
            sourceId: 'test',
            displayName: 'Mr. Armadillo',
            emails: const <fidl.EmailAddress>[
              const fidl.EmailAddress(value: 'mr_armadillo@example.com')
            ],
            phoneNumbers: <fidl.PhoneNumber>[],
          );
          fidl.Contact contact2 = new fidl.Contact(
            contactId: id,
            sourceContactId: '2',
            sourceId: 'test',
            displayName: 'Mr. Other Armadillo',
            emails: const <fidl.EmailAddress>[
              const fidl.EmailAddress(value: 'the_other_armadillo@example.com')
            ],
            phoneNumbers: const <fidl.PhoneNumber>[],
          );

          new ContactsStore()..addContact(contact1)..addContact(contact2);
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should update the contact if updateIfExists is true', () {
        String id = '1';
        fidl.Contact contact = new fidl.Contact(
          contactId: id,
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Mr. Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact updatedContact = new fidl.Contact(
          contactId: id,
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Mr. Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'the_other_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()..addContact(contact);
        expect(store.getContact(id), equals(contact));

        store.addContact(updatedContact, updateIfExists: true);
        expect(store.getContact(id), equals(updatedContact));
      });
    });

    group('removeContact', () {
      test('should remove the contact from the contact map', () {
        fidl.Contact contact1 = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = const fidl.Contact(
          contactId: 'contact3',
          sourceContactId: '3',
          sourceId: 'test',
          displayName: 'Capybara',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'largest_rodent@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()
          ..addContact(contact1)
          ..addContact(contact2);
        expect(store.containsContact(contact1.contactId), equals(true));
        expect(store.containsContact(contact2.contactId), equals(true));

        store.removeContact(contact1.contactId);

        expect(store.containsContact(contact1.contactId), equals(false));
        expect(store.containsContact(contact2.contactId), equals(true));
      });

      test('should remove the contact\'s display name from searchable values',
          () {
        fidl.Contact contact1 = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = const fidl.Contact(
          contactId: 'contact2',
          sourceContactId: '2',
          sourceId: 'test',
          displayName: 'Capybara',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'largest_rodent@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()
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

        store.removeContact(contact1.contactId);

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
        fidl.Contact contact1 = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'mr_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = const fidl.Contact(
          contactId: 'contact3',
          sourceContactId: '3',
          sourceId: 'test',
          displayName: 'Capybara',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'largest_rodent@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()
          ..addContact(contact1)
          ..addContact(contact2);

        List<String> c1Values = _getSearchableValues(contact1);
        List<String> c2Values = _getSearchableValues(contact2);
        for (String s in <String>[]..addAll(c1Values)..addAll(c2Values)) {
          expect(store.search(s), contains(s));
        }

        store.removeContact(contact1.contactId);

        for (String s in c1Values) {
          expect(store.search(s), isEmpty);
        }
        for (String s in c2Values) {
          expect(store.search(s), contains(s));
        }
      });

      test('should not remove other contacts with the same display name', () {
        fidl.Contact contact1 = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = const fidl.Contact(
          contactId: 'contact2',
          sourceContactId: '2',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'other_armadillo@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()
          ..addContact(contact1)
          ..addContact(contact2);

        Map<String, Set<fidl.Contact>> searchResult = store.search('Armadillo');
        expect(searchResult['Armadillo'], hasLength(2));
        expect(searchResult['Armadillo'], contains(contact1));
        expect(searchResult['Armadillo'], contains(contact2));

        store.removeContact(contact1.contactId);

        searchResult = store.search('Armadillo');
        expect(searchResult['Armadillo'], hasLength(1));
        expect(searchResult['Armadillo'], contains(contact2));
      });

      test('should not remove other contacts with the same searchable value',
          () {
        fidl.Contact contact1 = const fidl.Contact(
          contactId: 'contact1',
          sourceContactId: '1',
          sourceId: 'test',
          displayName: 'Armadillo',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'armadillo@example.com'),
            const fidl.EmailAddress(value: 'test')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        fidl.Contact contact2 = const fidl.Contact(
          contactId: 'contact2',
          sourceContactId: '2',
          sourceId: 'test',
          displayName: 'Capybara',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'capybara@example.com'),
            const fidl.EmailAddress(value: 'test'),
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        ContactsStore store = new ContactsStore()
          ..addContact(contact1)
          ..addContact(contact2);

        Map<String, Set<fidl.Contact>> searchResult = store.search('test');
        expect(searchResult['test'], hasLength(2));
        expect(searchResult['test'], contains(contact1));
        expect(searchResult['test'], contains(contact2));

        store.removeContact(contact1.contactId);

        searchResult = store.search('test');
        expect(searchResult['test'], hasLength(1));
        expect(searchResult['test'], contains(contact2));
      });
    });

    group('getAllContacts', () {
      test('should return a list of all contacts', () {
        List<fidl.Contact> contacts = _createContactList();
        ContactsStore store = new ContactsStore();

        // ignore: prefer_foreach
        for (fidl.Contact c in contacts) {
          store.addContact(c);
        }

        List<fidl.Contact> result = store.getAllContacts();
        expect(result, hasLength(contacts.length));
        for (fidl.Contact c in contacts) {
          expect(result, contains(c));
        }
      });

      test('should return an empty list if there aren\'t any contacts', () {
        ContactsStore store = new ContactsStore();
        expect(store.getAllContacts(), isEmpty);
      });

      test('should return contacts in case-insensitive alphabetical order', () {
        List<fidl.Contact> contacts = <fidl.Contact>[
          const fidl.Contact(
            contactId: 'index-1',
            sourceContactId: '1',
            sourceId: 'test',
            displayName: 'Bobby Bonilla',
            emails: const <fidl.EmailAddress>[],
            phoneNumbers: const <fidl.PhoneNumber>[],
          ),
          const fidl.Contact(
            contactId: 'index-0',
            sourceContactId: '0',
            sourceId: 'test',
            displayName: 'aaron aalderks',
            emails: const <fidl.EmailAddress>[],
            phoneNumbers: const <fidl.PhoneNumber>[],
          ),
          const fidl.Contact(
            contactId: 'index-3',
            sourceContactId: '3',
            sourceId: 'test',
            displayName: 'Zeke zephyr',
            emails: const <fidl.EmailAddress>[],
            phoneNumbers: const <fidl.PhoneNumber>[],
          ),
          const fidl.Contact(
            contactId: 'index-2',
            sourceContactId: '2',
            sourceId: 'test',
            displayName: 'calvin coolidge',
            emails: const <fidl.EmailAddress>[],
            phoneNumbers: const <fidl.PhoneNumber>[],
          ),
        ];
        ContactsStore store = new ContactsStore();

        // ignore: prefer_foreach
        for (fidl.Contact c in contacts) {
          store.addContact(c);
        }

        List<fidl.Contact> result = store.getAllContacts();
        for (int index = 0; index < result.length; index++) {
          expect(result[index].contactId, equals('index-$index'));
        }
      });
    });

    group('getContact', () {
      ContactsStore store;

      setUp(() async {
        store = new ContactsStore();

        // ignore: prefer_foreach
        for (fidl.Contact c in _createContactList()) {
          store.addContact(c);
        }
      });

      tearDown(() async {
        store = null;
      });

      test('should return the contact if it exists', () {
        fidl.Contact orca = const fidl.Contact(
          contactId: 'contact123',
          sourceContactId: '123',
          sourceId: 'test',
          displayName: 'orca',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'not_actually_a_whale@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        store.addContact(orca);

        fidl.Contact result = store.getContact(orca.contactId);
        expect(result, equals(orca));
      });

      test('should return null if there aren\'t any contacts', () {
        ContactsStore emptyStore = new ContactsStore();
        expect(emptyStore.getContact('someId'), isNull);
      });

      test('should return null if the contact doesn\'t exist', () {
        expect(store.getContact('notAnExistingId'), isNull);
      });
    });

    group('search', () {
      test('should return contacts with displayName and tag matching prefix',
          () {
        List<fidl.Contact> contacts = _createContactList();
        ContactsStore store = new ContactsStore();

        // ignore: prefer_foreach
        for (fidl.Contact c in contacts) {
          store.addContact(c);
        }

        Map<String, Set<fidl.Contact>> result = store.search('la');
        expect(result, hasLength(3));
        expect(result, contains('latte lover'));
        expect(result, contains('largest_rodent@example.com'));
        expect(result, contains('lady_of_the_sea@example.com'));
      });

      test('should return all searchable values if prefix is an empty string',
          () {
        List<fidl.Contact> contacts = _createContactList();
        ContactsStore store = new ContactsStore();

        // ignore: prefer_foreach
        for (fidl.Contact c in contacts) {
          store.addContact(c);
        }

        Map<String, Set<fidl.Contact>> result = store.search('');
        expect(result, hasLength(14));
        for (fidl.Contact c in contacts) {
          expect(result, contains(c.displayName.toLowerCase()));

          List<String> searchableValues = _getSearchableValues(c);
          for (String s in searchableValues) {
            expect(result, contains(s));
          }
        }
      });

      test('should return empty map if store is empty', () {
        ContactsStore emptyStore = new ContactsStore();
        expect(emptyStore.search('something'), isEmpty);
      });
    });

    group('containsContact', () {
      ContactsStore store;
      fidl.Contact c;

      setUp(() {
        store = new ContactsStore();
        c = const fidl.Contact(
          contactId: 'contact123',
          sourceContactId: '123',
          sourceId: 'test',
          displayName: 'orca',
          emails: const <fidl.EmailAddress>[
            const fidl.EmailAddress(value: 'not_actually_a_whale@example.com')
          ],
          phoneNumbers: const <fidl.PhoneNumber>[],
        );
        store.addContact(c);
      });

      tearDown(() {
        store = null;
      });

      test('should return true if contact is in store', () {
        expect(store.containsContact(c.contactId), isTrue);
      });

      test('should return false if contact is not in store', () {
        expect(store.containsContact('does not exist'), isFalse);
      });
    });
  });
}

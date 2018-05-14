// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:fidl_contacts_content_provider/fidl.dart'
    as fidl;

import 'prefix_tree.dart';

/// A [ContactsStore] that holds contacts objects.
/// It allows prefix search of the searchable fields, listing contacts
/// alphabetically based on display name, and retrieving specific contacts.
class ContactsStore {
  /// Map that stores the contact object given its ID
  final Map<String, fidl.Contact> _contactMap =
      new HashMap<String, fidl.Contact>();

  /// Takes the displayName as the key and a set of [fidl.Contact.contactId]s as
  /// the value in case there are multiple contacts with the same display name
  final SplayTreeMap<String, Set<String>> _displayNameIndex =
      new SplayTreeMap<String, Set<String>>(_compareDisplayNames);

  /// Index on the contact and it's source. Key is the [fidl.Contact.sourceId]
  /// and the value are a set of [fidl.Contact.contactId]s
  final Map<String, Set<String>> _contactSourceIndex = <String, Set<String>>{};

  /// The prefix tree that allows prefix searching through all searchable fields
  final PrefixTree<Set<fidl.Contact>> _prefixTree =
      new PrefixTree<Set<fidl.Contact>>();

  List<String> _getSearchableValues(fidl.Contact contact) {
    List<String> searchableValues = <String>[];
    if (contact != null) {
      // TODO: add back ability to search on parts of the users names SO-1018
      searchableValues = <String>[
        contact.displayName.trim(),
        contact.displayName.trim().toLowerCase()
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

  /// Add contact data to the store.
  ///
  /// The contact id must be unique but allows duplicates against the display
  /// name and searchable values.
  ///
  /// Searchable values are the values for the contact we want to be able to do
  /// a prefix search against, this list cannot be empty.
  ///
  /// [updateIfExists] allows the caller to update the value instead of adding
  /// it if it already exists in the contacts store.
  void addContact(fidl.Contact contact, {bool updateIfExists: false}) {
    _validateContact(contact, updateIfExists);

    String id = contact.contactId;
    String displayName = contact.displayName;
    List<String> searchableValues = _getSearchableValues(contact);

    // Since store doesn't know the specifics of the contact object, rather
    // than "updating" the one we have stored it's simpler to remove the old one
    // entirely and add the new one
    if (containsContact(id) && updateIfExists) {
      removeContact(id);
    }
    _contactMap[id] = contact;

    // Add to the displayName index
    _displayNameIndex[displayName] ??= new Set<String>();
    _displayNameIndex[displayName].add(contact.contactId);

    // Add to the source index
    _contactSourceIndex[contact.sourceId] ??= new Set<String>();
    _contactSourceIndex[contact.sourceId].add(contact.contactId);

    // Add all searchable values to the prefix tree
    for (String value in searchableValues) {
      _prefixTree[value] ??= new Set<fidl.Contact>();
      _prefixTree[value].add(contact);
    }
  }

  /// Remove the contact with the given [id] from the store
  void removeContact(String id) {
    fidl.Contact contact = _contactMap[id];
    if (contact == null) {
      return;
    }

    // Delete the old contact from all parts of the store
    // this means grabbing the old contact's display name and searchable
    // values and removing them as well as the old contact object from the store
    _contactMap.remove(id);

    String displayName = contact.displayName;
    Set<String> displayNameSet = _displayNameIndex[displayName]
      ..remove(contact.contactId);
    if (displayNameSet.isEmpty) {
      _displayNameIndex.remove(displayName);
    }

    Set<String> sourceContacts = _contactSourceIndex[contact.sourceId]
      ..remove(contact.contactId);
    if (sourceContacts.isEmpty) {
      _contactSourceIndex.remove(contact.sourceId);
    }

    List<String> searchableValues = _getSearchableValues(contact);
    for (String value in searchableValues) {
      Set<fidl.Contact> prefixContacts = _prefixTree[value];

      // A contact may have duplicate emails, the set may have already been
      // removed
      if (prefixContacts != null) {
        prefixContacts.remove(contact);
        if (prefixContacts.isEmpty) {
          _prefixTree.remove(value);
        }
      }
    }
  }

  /// Returns the list of all the contacts from the source at [sourceId]
  List<fidl.Contact> getContactsFromSource(String sourceId) {
    return _contactSourceIndex[sourceId]?.map(getContact)?.toList() ??
        <fidl.Contact>[];
  }

  /// Return the list of all contacts sorted by displayName
  List<fidl.Contact> getAllContacts() {
    return _displayNameIndex.values
        .expand((Set<String> contactIds) => contactIds)
        .map(getContact)
        .toList();
  }

  /// Return the contact that matches the given [id] otherwise return null
  fidl.Contact getContact(String id) => _contactMap[id];

  /// Return whether or not the store contains a contact with the given [id]
  bool containsContact(String id) => _contactMap.containsKey(id);

  /// Return the result of the case-insensitive alphabetical comparison of two contacts' display names
  static int _compareDisplayNames(String lhs, String rhs) {
    return lhs.toLowerCase().compareTo(rhs.toLowerCase());
  }

  /// Searches through all searchable values that start with the given [prefix]
  /// Returns a map with the matching strings as keys and the contacts
  /// associated with each matched string as its value.
  Map<String, Set<fidl.Contact>> search(String prefix) =>
      _prefixTree.search(prefix);

  void _validateContact(fidl.Contact contact, bool isValidIfExists) {
    if (contact == null) {
      throw new ArgumentError.notNull('contact');
    }

    String id = contact.contactId;
    if (id == null || id.isEmpty) {
      throw new ArgumentError('id cannot be null or empty');
    } else if (_contactMap.containsKey(id) && !isValidIfExists) {
      throw new ArgumentError('$id already exists in ContactsStore');
    }

    String displayName = contact.displayName;
    if (displayName == null || displayName.isEmpty) {
      throw new ArgumentError('displayName cannot be null or empty');
    }

    List<String> searchableValues;
    try {
      searchableValues = _getSearchableValues(contact);
    } on Exception catch (e) {
      throw new ArgumentError('Error extracting searchable values. error = $e');
    }
    if (searchableValues == null || searchableValues.isEmpty) {
      throw new ArgumentError('searchableValues cannot be null or empty');
    }
  }
}

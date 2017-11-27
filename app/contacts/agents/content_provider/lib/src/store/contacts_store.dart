// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'prefix_tree.dart';

/// A [ContactsStore] that holds contacts objects.
/// It allows prefix search of the searchable fields, listing contacts
/// alphabetically based on display name, and retrieving specific contacts.
///
/// Note: ideally this would directly take a Contact class defined by the
/// FIDL interface however if we have a dependency on the FIDL defined
/// classes then it cannot be easily unit tested at this time.
///
/// TODO(meiyili): remove generic once using FIDL defined structs no longer
/// prevents local host unit tests (SO-746).
class ContactsStore<T> {
  /// Map that stores the contact object given its ID
  final Map<String, T> _contactMap = new HashMap<String, T>();

  /// Takes the displayName as the key and a set of contact ids as the value
  /// in case there are multiple contacts with the same display name
  final SplayTreeMap<String, Set<T>> _displayNameIndex =
      new SplayTreeMap<String, Set<T>>();

  /// The prefix tree that allows prefix searching through all searchable fields
  final PrefixTree<Set<T>> _prefixTree = new PrefixTree<Set<T>>();

  /// Add contact data to the store.
  /// [id] must be unique but allows duplicates against the [displayName]
  /// and [searchableValues]. [searchableValues] are the values for the contact
  /// we want to be able to do a prefix search against, this list cannot be
  /// empty.
  ///
  /// [updateIfExists] allows the caller to update the value instead of adding
  /// it if it already exists in the contacts store.
  ///
  /// Note: ideally this would directly take a Contact class defined by the
  /// FIDL interface however if we have a dependency on the FIDL defined
  /// classes then it cannot be easily unit tested at this time
  ///
  /// TODO(meiyili): once using FIDL defined structs no long prevents local
  /// unit tests change this to addContact(Contact contact) (SO-746).
  void addContact(
    String id,
    String displayName,
    List<String> searchableValues,
    T contact, {
    bool updateIfExists: false,
  }) {
    _validateAddContactArgs(
      id,
      displayName,
      searchableValues,
      contact,
      updateIfExists,
    );

    // Store the entire contact information in the map against its id
    T contactToAdd = _contactMap[id] ?? contact;
    _contactMap[id] = contactToAdd;

    // Add to the displayName index
    _displayNameIndex[displayName] ??= new Set<T>();
    _displayNameIndex[displayName].add(contactToAdd);

    // Add all searchable values to the prefix tree
    for (String value in searchableValues) {
      _prefixTree[value] ??= new Set<T>();
      _prefixTree[value].add(contactToAdd);
    }
  }

  /// Return the list of all contacts sorted by displayName
  List<T> getAllContacts() {
    return _displayNameIndex.values
        .expand((Set<T> contacts) => contacts)
        .toList();
  }

  /// Return the contact that matches the given [id] otherwise return null
  T getContact(String id) => _contactMap[id];

  /// Return whether or not the store contains a contact with the given [id]
  bool containsContact(String id) => _contactMap.containsKey(id);

  /// Searches through all searchable values that start with the given [prefix]
  /// Returns a map with the matching strings as keys and the contacts
  /// associated with each matched string as its value.
  Map<String, Set<T>> search(String prefix) => _prefixTree.search(prefix);

  void _validateAddContactArgs(
    String id,
    String displayName,
    List<String> searchableValues,
    T contact,
    bool isValidIfExists,
  ) {
    if (id == null || id.isEmpty) {
      throw new ArgumentError('id cannot be null or empty');
    } else if (_contactMap.containsKey(id) && !isValidIfExists) {
      throw new ArgumentError('$id already exists in ContactsStore');
    }
    if (displayName == null || displayName.isEmpty) {
      throw new ArgumentError('displayName cannot be null or empty');
    }
    if (searchableValues == null || searchableValues.isEmpty) {
      throw new ArgumentError('searchableValues cannot be null or empty');
    }
    if (contact == null) {
      throw new ArgumentError.notNull('contact');
    }
  }
}

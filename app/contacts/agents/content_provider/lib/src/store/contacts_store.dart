// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:meta/meta.dart';

import 'prefix_tree.dart';

/// Returns the id of the contact
typedef String GetId<T>(T contact);

/// Returns the display name of the contact
typedef String GetDisplayName<T>(T contact);

/// Returns all the searchable values for the contact
typedef List<String> GetSearchableValues<T>(T contact);

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
      new SplayTreeMap<String, Set<T>>(_compareDisplayNames);

  /// The prefix tree that allows prefix searching through all searchable fields
  final PrefixTree<Set<T>> _prefixTree = new PrefixTree<Set<T>>();

  // Methods to retrieve the key values of the contact
  final GetId<T> _getId;
  final GetDisplayName<T> _getDisplayName;
  final GetSearchableValues<T> _getSearchableValues;

  /// Create a contact store instance that takes methods to derive the necessary
  /// contact data from type [T] to index on.
  ///
  /// Note: ideally this would directly take a Contact class defined by the
  /// FIDL interface however if we have a dependency on the FIDL defined
  /// classes then it cannot be easily unit tested at this time
  ///
  /// TODO(meiyili): once using FIDL defined structs no long prevents local
  /// unit tests change this to addContact(Contact contact) (SO-746).
  ContactsStore({
    @required GetId<T> getId,
    @required GetDisplayName<T> getDisplayName,
    @required GetSearchableValues<T> getSearchableValues,
  })
      : assert(getId != null),
        assert(getDisplayName != null),
        assert(getSearchableValues != null),
        _getId = getId,
        _getDisplayName = getDisplayName,
        _getSearchableValues = getSearchableValues;

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
  void addContact(T contact, {bool updateIfExists: false}) {
    _validateContact(contact, updateIfExists);

    String id = _getId(contact);
    String displayName = _getDisplayName(contact);
    List<String> searchableValues = _getSearchableValues(contact);

    // Since store doesn't know the specifics of the contact object, rather
    // than "updating" the one we have stored it's simpler to remove the old one
    // entirely and add the new one
    if (containsContact(id) && updateIfExists) {
      removeContact(id);
    }
    _contactMap[id] = contact;

    // Add to the displayName index
    _displayNameIndex[displayName] ??= new Set<T>();
    _displayNameIndex[displayName].add(contact);

    // Add all searchable values to the prefix tree
    for (String value in searchableValues) {
      _prefixTree[value] ??= new Set<T>();
      _prefixTree[value].add(contact);
    }
  }

  /// Remove the contact with the given [id] from the store
  void removeContact(String id) {
    T contact = _contactMap[id];
    if (contact == null) {
      return;
    }

    // Delete the old contact from all parts of the store
    // this means grabbing the old contact's display name and searchable
    // values and removing them as well as the old contact object from the store
    _contactMap.remove(id);

    String displayName = _getDisplayName(contact);
    Set<T> displayNameSet = _displayNameIndex[displayName]..remove(contact);
    if (displayNameSet.isEmpty) {
      _displayNameIndex.remove(displayName);
    }

    List<String> searchableValues = _getSearchableValues(contact);
    for (String value in searchableValues) {
      Set<T> prefixContacts = _prefixTree[value];

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

  /// Return the result of the case-insensitive alphabetical comparison of two contacts' display names
  static int _compareDisplayNames(String lhs, String rhs) {
    return lhs.toLowerCase().compareTo(rhs.toLowerCase());
  }

  /// Searches through all searchable values that start with the given [prefix]
  /// Returns a map with the matching strings as keys and the contacts
  /// associated with each matched string as its value.
  Map<String, Set<T>> search(String prefix) => _prefixTree.search(prefix);

  void _validateContact(T contact, bool isValidIfExists) {
    if (contact == null) {
      throw new ArgumentError.notNull('contact');
    }

    String id;
    String displayName;
    List<String> searchableValues;
    try {
      id = _getId(contact);
      displayName = _getDisplayName(contact);
      searchableValues = _getSearchableValues(contact);
    } on Exception catch (e) {
      throw new ArgumentError('Error extracting contact details. error = $e');
    }

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
  }
}

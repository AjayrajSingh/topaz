// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// A data model class that represents a contact list item.
/// It contains only the data needed for displaying a list item and retrieving
/// more information about the given contact later on.
class ContactItemStore {
  /// Delimiter to join the name components
  static const String nameDelimiter = ' ';

  /// If the matched portion of this contact is part of the contact's name
  /// when false it is assumed this contact was matched on its detail.
  /// When true matchedNameIndex must be within range of [ 0, names.length ).
  final bool isMatchedOnName;

  /// The part of the name that was matched on
  final int matchedNameIndex;

  /// Unique identifier for the contact.
  final String id;

  /// The components that make up the full name of the contact to be
  /// displayed
  final List<String> names;

  /// Secondary piece of information to show in the list item which can be
  /// anything from email to phone number.
  ///
  /// Allows the UI to customize this information given the context of the
  /// module.
  final String detail;

  /// Avatar photoUrl for the contact.
  final String photoUrl;

  /// Creates an instance of a [ContactItemStore]
  ContactItemStore({
    @required this.id,
    @required this.names,
    @required this.isMatchedOnName,
    this.matchedNameIndex: -1,
    this.detail: '',
    this.photoUrl: '',
  })  : assert(id != null && id.isNotEmpty),
        assert(names != null && names.isNotEmpty),
        assert(isMatchedOnName != null) {
    if (isMatchedOnName &&
        (matchedNameIndex < 0 || matchedNameIndex >= names.length)) {
      throw new Exception('ContactListItem: matchedNameIndex must in range of '
          'names list when isMatchedOnName is true');
    }
  }

  /// The user's full name
  String get fullName => names.join(nameDelimiter);
}

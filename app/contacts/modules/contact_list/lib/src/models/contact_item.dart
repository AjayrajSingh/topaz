// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// A data model class that represents a contact list item.
/// It contains only the data needed for displaying a list item and retrieving
/// more information about the given contact later on.
class ContactItem {
  final String _displayName;

  /// Unique identifier for the contact.
  final String id;

  /// Avatar photoUrl for the contact.
  final String photoUrl;

  /// Creates an instance of a [ContactItem]
  ContactItem({
    @required this.id,
    @required String displayName,
    this.photoUrl,
  })
      : assert(id != null && id.isNotEmpty),
        assert(displayName != null && displayName.trim().isNotEmpty),
        _displayName = displayName.trim();

  /// The first letter of the display name, or '#' if display name begins with a number.
  String get firstLetter {
    bool isNumber = '0123456789'.contains(_displayName[0]);
    return isNumber ? '#' : _displayName[0].toUpperCase();
  }

  /// List display name for the contact.
  String get displayName => _displayName;
}

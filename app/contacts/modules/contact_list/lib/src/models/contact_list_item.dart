// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// A data model class that represents a contact list item.
/// It contains only the data needed for displaying a list item and retrieving
/// more information about the given contact later on.
class ContactListItem {
  /// Unique identifier for the contact.
  final String id;

  /// List display name for the contact.
  final String displayName;

  /// Avatar photoUrl for the contact.
  final String photoUrl;

  /// Creates an instance of a [ContactListItem]
  ContactListItem({
    @required this.id,
    @required this.displayName,
    this.photoUrl: '',
  })
      : assert(id != null && id.isNotEmpty),
        assert(displayName != null && displayName.isNotEmpty);

  /// The first letter of the display name
  String get firstLetter => displayName[0];
}

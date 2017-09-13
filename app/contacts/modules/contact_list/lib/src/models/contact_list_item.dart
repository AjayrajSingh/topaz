// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  ContactListItem({this.id, this.displayName, this.photoUrl = ''});
}

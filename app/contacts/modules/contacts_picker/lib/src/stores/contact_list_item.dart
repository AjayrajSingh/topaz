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

  /// Secondary piece of information to show in the list item which can be
  /// anything from email to phone number.
  ///
  /// Allows the UI to customize this information given the context of the
  /// module.
  final String detail;

  /// Avatar photoUrl for the contact.
  final String photoUrl;

  /// Creates an instance of a [ContactListItem]
  ContactListItem({
    @required this.id,
    @required this.displayName,
    this.detail,
    this.photoUrl,
  })
      : assert(id != null && id.isNotEmpty),
        assert(displayName != null && displayName.isNotEmpty);
}

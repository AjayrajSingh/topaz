// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

/// The link data that contains the entity reference for the contact
class LinkData {
  /// The entity reference for the contact
  final String entityReference;

  /// Constructor
  const LinkData({
    this.entityReference,
  });

  /// Create a [LinkData] object from a json string, if the json string is
  /// malformed it will return null
  factory LinkData.fromJson(String encoded) {
    Object decodedJson = json.decode(encoded);
    if (decodedJson is Map && decodedJson['contact_entity_reference'] != null) {
      return new LinkData(
          entityReference: decodedJson['contact_entity_reference']);
    } else {
      return null;
    }
  }
}

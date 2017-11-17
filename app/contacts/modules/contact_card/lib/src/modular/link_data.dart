// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

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
  factory LinkData.fromJson(String json) {
    Object decodedJson = JSON.decode(json);
    if (decodedJson is Map && decodedJson['entityReference'] != null) {
      return new LinkData(entityReference: decodedJson['entityReference']);
    } else {
      return null;
    }
  }
}

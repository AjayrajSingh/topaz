// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

/// The type of detail to show with the contact's display name
enum DetailType {
  /// Primary email of the contact
  email,

  /// Primary phone number of the contact
  phoneNumber,

  /// Custom contact information
  custom,
}

/// The link data used by this module to communicate with other modules, it
/// contains incoming data about the current contacts query (i.e prefix and
/// detail type) and outgoing data about the contact that is select.
///
/// TODO(meiyili): add selected contact info to link data when integrating with
/// chat module
class LinkData {
  /// The prefix used to filter contacts
  final String prefix;

  /// Detail to show with the contact's display name
  final DetailType detailType;

  /// Constructor
  const LinkData({
    this.prefix,
    this.detailType: DetailType.email,
  });

  /// Create a new [LinkData] from the given json.
  ///
  /// Typically, the json data will come from the root Link of this module.
  factory LinkData.fromJson(String encoded) {
    String prefix = '';
    DetailType detailType = DetailType.values[0];

    Object jsonObject = json.decode(encoded);
    if (jsonObject is Map<String, dynamic>) {
      if (jsonObject['prefix'] is Map<String, Object>) {
        prefix = jsonObject['prefix']['content'];
      }

      if (jsonObject['detailType'] is Map<String, Object>) {
        switch (jsonObject['detailType']['content']) {
          case 'email':
            detailType = DetailType.email;
            break;

          case 'phoneNumber':
            detailType = DetailType.phoneNumber;
            break;

          case 'custom':
            detailType = DetailType.custom;
            break;
        }
      }
    }

    return new LinkData(
      prefix: prefix,
      detailType: detailType,
    );
  }
}

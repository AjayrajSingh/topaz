// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The type of detail to show with the contact's display name
enum DetailType {
  /// Primary email of the contact
  email,

  /// Primary phone number of the contact
  phoneNumber,

  /// Custom contact information
  custom,
}

/// Data for filtering a list of contacts
class FilterEntityData {
  /// The prefix used to filter contacts
  String prefix;

  /// Detail to show with the contact's display name
  DetailType detailType;

  /// Constructor
  FilterEntityData({
    this.prefix = '',
    this.detailType = DetailType.email,
  });
}

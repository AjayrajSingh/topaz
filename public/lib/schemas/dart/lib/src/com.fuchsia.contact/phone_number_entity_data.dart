// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// The Entity schema for a phone number
class PhoneNumberEntityData {
  /// Phone number, e.g. 911, 1-408-111-2222
  final String number;

  /// Optional label to give for the phone entry, e.g. Cell, Home, Work...
  final String label;

  /// Constructor
  PhoneNumberEntityData({
    @required this.number,
    this.label,
  }) : assert(number != null && number.isNotEmpty);
}

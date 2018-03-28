// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// The Entity Schema for an email address
class EmailEntityData {
  /// Email address, e.g. littlePuppyCoco@cute.org
  final String value;

  /// Optional label to give for the email, e.g. Work, Personal...
  final String label;

  /// Constructor
  EmailEntityData({
    @required this.value,
    this.label,
  }) : assert(value != null && value.isNotEmpty);
}

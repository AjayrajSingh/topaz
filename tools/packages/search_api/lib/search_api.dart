// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// Generic Search API class
// We may be adding more members to this class later
// ignore: one_member_abstracts
abstract class SearchAPI {
  /// Returns a list of image URLs, de-duped for the selection UI logic
  Future<List<String>> images({String query});
}

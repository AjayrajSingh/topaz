// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'names.dart';

final Random _rng = new Random();

/// Used by Fixtures for generating names.
///
/// A [String] name can be randomly generated with calls to [generateName].
///
///     String name = generateName();
///
/// When a name is 'generated' it is derived from a random first name
/// [kFirstNames], and random last name [kSurnames].
String generateName() {
  String first;
  int firstIndex;

  firstIndex = _rng.nextInt(kFirstNames.length);
  first = kFirstNames[firstIndex];

  int lastIndex = _rng.nextInt(kSurnames.length);
  String last = kSurnames[lastIndex];

  return '$first $last';
}

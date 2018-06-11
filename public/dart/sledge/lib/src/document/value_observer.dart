// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// More members will likely be added later on.
// ignore_for_file: one_member_abstracts

/// Observes values.
abstract class ValueObserver {
  /// Called whenever the observed value changes.
  void valueWasChanged();
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

/// Signature of tab ownership change callbacks.
typedef void OwnershipChangeCallback(TabData data);

/// Data associated with a tab.
class TabData {
  /// The tab's color.
  final Color color;

  /// Called when the owner of the tab changed.
  OwnershipChangeCallback onOwnerChanged;

  /// Constructor.
  TabData(this.color);
}

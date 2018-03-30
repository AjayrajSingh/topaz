// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.documents/documents.dart' as doc_fidl;

/// An item that can be selected, mult-selected, and interacted with
abstract class SelectableItem extends StatelessWidget {
  /// Document attached to this item view
  final doc_fidl.Document doc;

  /// True if this document is currently selected or multi-selected
  final bool selected;

  /// Function to call when item is pressed
  final VoidCallback onPressed;

  /// Function to call when item is double tapped
  final VoidCallback onDoubleTap;

  /// Function to call when item is pressed
  final VoidCallback onLongPress;

  /// Whether to show the checkbox for multi-select
  final bool hideCheckbox;

  /// Constructor
  const SelectableItem({
    Key key,
    @required this.doc,
    @required this.selected,
    this.onPressed,
    this.onDoubleTap,
    this.onLongPress,
    this.hideCheckbox,
  })
      : assert(doc != null),
        assert(selected != null),
        super(key: key);
}

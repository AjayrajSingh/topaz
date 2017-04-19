// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';

/// Class describing a surface node: id, view, parent and surface relationship
class ChildViewNode {
  /// The ID of this child
  final int id;

  /// Connection to underlying view
  final ChildViewConnection connection;

  /// ID of parent
  final int parentId;

  /// Relationship to parent
  String relationship;

  /// ChildViewNode
  /// @params connection The Mozart View
  /// @params id The id of this view
  /// @params parentId The id of the parent surface's view
  /// @params relationship The relationship between this view and the parent
  ChildViewNode(this.connection, this.id, this.parentId, this.relationship);
}

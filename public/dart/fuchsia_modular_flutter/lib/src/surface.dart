// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';

/// Defines a view surface for a mod.
///
/// The [childViewConnection] holds the actual scenic view for the mod.
class Surface {
  /// Holds the unique id of the surface.
  final String id;

  /// Holds the [SurfaceInfo] of the surface.
  final SurfaceInfo info;

  /// Holds the [ChildViewConnection] assigned to the surface.
  ChildViewConnection childViewConnection;

  /// Constructor.
  Surface({
    this.id,
    this.info,
    this.childViewConnection,
  });

  /// Holds the focused state of the surface.
  bool focused = false;
}

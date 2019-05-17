// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';
import 'package:tiler/tiler.dart';
import 'module_info.dart';

/// Depends on the implementation of the Layout and the Presenter.
/// Declared by the Presenter because multiple layouts can use the same
/// Presenter.
class TileLayoutModel {
  /// The tiling layout model.
  final TilerModel<ModuleInfo> model;

  /// Maps a surface id to its view.
  final BuiltMap<String, ChildViewConnection> connections;

  /// Constructor for a tiling layout model.
  TileLayoutModel({@required this.model, @required this.connections});
}

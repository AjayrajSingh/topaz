// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tiler/tiler.dart';
import '../tile_model/module_info.dart';

/// Recommend alternative layouts
class LayoutSuggestionUpdate {
  /// List of suggestions for new [TilerModel]s
  final UnmodifiableListView<TilerModel<ModuleInfo>> models;

  /// Constructor for a layout suggestions update.
  LayoutSuggestionUpdate({@required this.models});
}

// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:built_collection/built_collection.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:tiler/tiler.dart';

import '../layout.dart';
import '../tile_model/module_info.dart';
import '../tile_model/tile_layout_model.dart';
import '../tile_presenter/tile_presenter.dart';
import 'layout_policy.dart';
import 'layout_store.dart';
import 'layout_utils.dart';

// The user has requested a different layout.
typedef UserLayoutRequestCallback = void Function(TilerModel<ModuleInfo>);

/// The layout strategy manages a model of the layout that is shared with the
/// Presenter through the TileLayoutModel.
class DejaLayout extends Layout {
  var _tilerModel = TilerModel<ModuleInfo>();
  List<TilerModel<ModuleInfo>> _tilerModelSuggestions = [];
  final _connections = <String, ChildViewConnection>{};
  final _layoutPolicy = LayoutPolicy(layoutStore: LayoutStore());

  /// Tiling layout presenter
  TilePresenter presenter;

  /// Construct a Layout Manage that uses the Deja layout algorithm.
  /// Deja stores past layouts and matches them for the
  /// new layout when views are added or removed.
  DejaLayout({
    RemoveSurfaceCallback removeSurface,
    FocusChangeCallback changeFocus,
  }) : super(
          removeSurface: removeSurface,
          changeFocus: changeFocus,
        ) {
    presenter = TilePresenter(
        removeSurfaceCallback: removeSurface,
        changeFocusCallback: changeFocus,
        requestLayoutCallback: _userLayoutRequest);
  }

  /// Called by Modular
  @override
  void addSurface({
    String surfaceId,
    String intent,
    ChildViewConnection view,
    UnmodifiableListView<String> parameters,
  }) {
    final content = ModuleInfo(
      modName: surfaceId,
      intent: intent,
      parameters: parameters,
    );

    // Find the largest tile in the _tilerModel and have our content split
    // and insert itself there.
    splitLargestContent(_tilerModel, content);
    final tilerModels = _layoutPolicy.getLayout(_tilerModel);
    _tilerModel = tilerModels.first;
    _tilerModelSuggestions = tilerModels.take(4).toList();
    _connections[surfaceId] = view;
    _onLayoutChange();
    presenter.onSuggestionChange(_tilerModelSuggestions);
  }

  /// Called by Modular
  @override
  void deleteSurface(String surfaceId) {
    final tile = findContent(_tilerModel, surfaceId);
    if (tile != null) {
      _tilerModel.remove(tile);
    }
    _connections.remove(surfaceId);
    // Regenerate Layout Suggestions.
    final tilerModels = _layoutPolicy.getLayout(_tilerModel);
    _tilerModel = tilerModels.first;
    _tilerModelSuggestions = tilerModels.take(4).toList();
    _onLayoutChange();
    presenter.onSuggestionChange(_tilerModelSuggestions);
  }

  /// A utility to send the layout to the presenter
  void _onLayoutChange() {
    presenter.onLayoutChange(TileLayoutModel(
        model: _tilerModel, connections: BuiltMap(_connections)));
  }

  /// Presenter is asking that this new layout be made active. This follows some
  /// user editing or re-arranging.
  void _userLayoutRequest(TilerModel<ModuleInfo> model) {
    final modsToRemove = getModsDifference(_tilerModel, model);
    _tilerModel = model;
    if (modsToRemove.isNotEmpty) {
      removeSurface(modsToRemove);
      // Regenerate Layout Suggestions.
      final tilerModels = _layoutPolicy.getLayout(_tilerModel);
      _tilerModel = tilerModels.first;
      _tilerModelSuggestions = tilerModels.take(4).toList();
      presenter.onSuggestionChange(_tilerModelSuggestions);
    }
    _onLayoutChange();
    _layoutPolicy.write(_tilerModel);
  }
}

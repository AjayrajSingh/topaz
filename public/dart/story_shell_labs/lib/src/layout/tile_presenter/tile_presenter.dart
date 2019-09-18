// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:built_collection/built_collection.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:tiler/tiler.dart';

import '../deja_layout/deja_layout.dart';
import '../layout.dart';
import '../presenter.dart';
import '../tile_model/module_info.dart';
import '../tile_model/tile_layout_model.dart';
import 'layout_suggestions_update.dart';

/// This class is part of a flutter-based presenter.
/// It converts callbacks from [Layout] into broadcast streams which are
/// easier for Flutter Widgets to work with.
class TilePresenter extends Presenter<TileLayoutModel> {
  /// Called when a layout is requested.
  UserLayoutRequestCallback requestLayoutCallback;

  TileLayoutModel _current = TileLayoutModel(
      model: TilerModel<ModuleInfo>(),
      connections: BuiltMap(<String, ChildViewConnection>{}));
  List<TilerModel<ModuleInfo>> _suggestions = [];

  // Stream controllers
  final _layoutSuggestionController =
      StreamController<LayoutSuggestionUpdate>.broadcast();
  final _updateController = StreamController<TileLayoutModel>.broadcast();

  /// Streams the current layout.
  Stream<TileLayoutModel> get update => _updateController.stream;

  /// Get the current layout.
  TileLayoutModel get currentState => _current;

  /// Constructor for a tiling presenter.
  TilePresenter({
    RemoveSurfaceCallback removeSurfaceCallback,
    FocusChangeCallback changeFocusCallback,
    this.requestLayoutCallback,
  }) : super(
            removeSurfaceCallback: removeSurfaceCallback,
            changeFocusCallback: changeFocusCallback);

  /// Call when the presenter is no longer needed to close streams.
  void dispose() {
    _updateController.close();
  }

  /// Streams layout suggestion updates.
  Stream<LayoutSuggestionUpdate> get suggestionsUpdate =>
      _layoutSuggestionController.stream;

  /// Get current layoutsuggestions.
  LayoutSuggestionUpdate get currentSuggestionsState => LayoutSuggestionUpdate(
        models: UnmodifiableListView(_suggestions),
      );

  @override
  void onLayoutChange(TileLayoutModel layoutModel) {
    // publish on stream for ease of use on Flutter side
    _current = layoutModel;
    _updateController.add(layoutModel);
  }

  /// Called with new layout suggestions.
  void onSuggestionChange(Iterable<TilerModel<ModuleInfo>> models) {
    _suggestions = models;
    // publish on stream for ease of use on Flutter side
    _layoutSuggestionController
        .add(LayoutSuggestionUpdate(models: UnmodifiableListView(models)));
  }

  /// Request a layout.
  void requestLayout(TilerModel<ModuleInfo> model) =>
      requestLayoutCallback(model);

  @override
  void changeFocus(String modName, {bool focus = false}) =>
      changeFocusCallback(modName, focus);

  @override
  void removeSurface(Iterable<String> surfaces) =>
      removeSurfaceCallback(surfaces);
}

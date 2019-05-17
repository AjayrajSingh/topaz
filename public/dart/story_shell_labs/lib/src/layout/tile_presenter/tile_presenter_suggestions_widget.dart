// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:tiler/tiler.dart';

import '../tile_model/module_info.dart';
import 'layout_suggestions_update.dart';
import 'tile_presenter.dart';

/// Widget for displaying layout suggestions.
@immutable
class LayoutSuggestionsWidget extends StatelessWidget {
  /// Presenter for a tile.
  final TilePresenter presenter;

  /// Returns border color for a given surface id.
  final Color Function(String modName) colorForMod;

  /// Called when a suggestion is selected.
  final void Function(TilerModel) onSelect;

  /// Constructor for a layout suggestions widget.
  const LayoutSuggestionsWidget({
    @required this.presenter,
    @required this.onSelect,
    @required this.colorForMod,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<LayoutSuggestionUpdate>(
        stream: presenter.suggestionsUpdate,
        initialData: presenter.currentSuggestionsState,
        builder: (context, snapshot) {
          print('suggested models: ${snapshot.data.models}');
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: snapshot.data.models.map(_buildSuggestion).toList(),
          );
        },
      );

  Widget _buildSuggestion(TilerModel<ModuleInfo> model) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        elevation: 24,
        color: Colors.white,
        child: AspectRatio(
          aspectRatio: 4.0 / 3.0,
          child: Stack(
            children: <Widget>[
              Container(
                color: Color(0xFFFAFAFA),
                margin: EdgeInsets.all(1.0),
                padding: EdgeInsets.all(1.0),
                child: Tiler(
                  sizerThickness: 0,
                  model: model,
                  chromeBuilder: (BuildContext context, TileModel tile) {
                    return Padding(
                      padding: EdgeInsets.all(1),
                      child: Container(
                        color: colorForMod(tile.content.modName),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      onSelect(model);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

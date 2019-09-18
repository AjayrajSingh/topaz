// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:story_shell_labs_lib/layout/tile_model.dart';
import 'package:tiler/tiler.dart';

import '../tile_model/module_info.dart';
import 'layout_suggestions_update.dart';
import 'tile_presenter.dart';

/// Widget for displaying layout suggestions.
@immutable
class LayoutSuggestionsWidget extends StatelessWidget {
  /// Presenter for a tile.
  final TilePresenter presenter;

  /// Value notifier with name of currently focused mod
  final ValueNotifier<String> focusedMod;

  /// Called when a suggestion is selected.
  final void Function(TilerModel) onSelect;

  /// Constructor for a layout suggestions widget.
  const LayoutSuggestionsWidget({
    @required this.presenter,
    @required this.onSelect,
    @required this.focusedMod,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<LayoutSuggestionUpdate>(
        stream: presenter.suggestionsUpdate,
        initialData: presenter.currentSuggestionsState,
        builder: (context, snapshot) => Row(
          mainAxisSize: MainAxisSize.min,
          children: snapshot.data.models
              .map(cloneTiler)
              .map(_buildSuggestion)
              .toList(),
        ),
      );

  Widget _buildSuggestion(TilerModel<ModuleInfo> model) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: _LayoutSuggestionButton(
          model: model,
          focusedMod: focusedMod,
          onSelect: onSelect,
        ),
      );
}

class _LayoutSuggestionButton extends StatefulWidget {
  const _LayoutSuggestionButton({
    @required this.model,
    @required this.focusedMod,
    @required this.onSelect,
  });

  final TilerModel<ModuleInfo> model;
  final ValueNotifier<String> focusedMod;
  final void Function(TilerModel) onSelect;

  @override
  _LayoutSuggestionButtonState createState() => _LayoutSuggestionButtonState();
}

class _LayoutSuggestionButtonState extends State<_LayoutSuggestionButton> {
  final _touching = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onSelect(widget.model);
      },
      onTapDown: (_) {
        _touching.value = true;
      },
      onTapCancel: () {
        _touching.value = false;
      },
      onTapUp: (_) {
        _touching.value = false;
      },
      child: AnimatedBuilder(
          animation: _touching,
          builder: (_, __) {
            final touching = _touching.value;
            final background = touching ? Colors.black : Colors.white;
            final foreground = touching ? Colors.white : Colors.black;
            final highlighted = Color(0xFFFF8BCB);
            return Material(
              elevation: 24,
              color: background,
              child: AspectRatio(
                aspectRatio: 2.0,
                child: Padding(
                  padding: EdgeInsets.all(1.0),
                  child: Tiler(
                    sizerThickness: 0,
                    model: widget.model,
                    chromeBuilder: (BuildContext context, TileModel tile) {
                      return AnimatedBuilder(
                          animation: widget.focusedMod,
                          builder: (_, __) {
                            return Container(
                              margin: EdgeInsets.all(1),
                              color: widget.focusedMod.value ==
                                      tile.content.modName
                                  ? highlighted
                                  : foreground,
                            );
                          });
                    },
                  ),
                ),
              ),
            );
          }),
    );
  }
}

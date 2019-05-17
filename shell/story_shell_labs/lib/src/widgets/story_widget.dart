// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;
import 'package:tiler/tiler.dart';
import 'package:story_shell_labs_lib/layout/tile_model.dart';
import 'package:story_shell_labs_lib/layout/tile_presenter.dart';

final List<Color> _kColors = [
  Colors.red,
  Colors.blue,
  Colors.yellow,
  Colors.green,
  Colors.pink,
  Colors.orange,
  Colors.purple,
];

class StoryWidget extends StatefulWidget {
  final TilePresenter presenter;

  const StoryWidget({@required this.presenter});

  @override
  _StoryWidgetState createState() => _StoryWidgetState();
}

class _StoryWidgetState extends State<StoryWidget> {
  /// Used for resizing locally, moving, etc when in edit mode.
  /// Once out of edit mode, LayoutBloc is notified with the updated model.
  TilerModel<ModuleInfo> _tilerModel;
  BuiltMap<String, ChildViewConnection> _connections;
  StreamSubscription _tilerUpdateListener;
  bool _isEditing = false;
  OverlayEntry _layoutSuggestionsOverlay;
  Map<String, Color> _modNamesToColors;
  Map<String, Color> _parametersToColors;
  final ValueNotifier _focusedMod = ValueNotifier(null);

  @override
  void initState() {
    _resetTilerModel();

    _tilerUpdateListener = widget.presenter.update.listen((update) {
      setState(() {
        _isEditing = false;
        _resetTilerModel(update: update);
      });
      updateLayoutSuggestionsOverlayVisibility();
    });
    super.initState();
  }

  @override
  void dispose() {
    _tilerUpdateListener.cancel();
    super.dispose();
  }

  void _resetTilerModel({TileLayoutModel update}) {
    update ??= widget.presenter.currentState;
    _tilerModel = update.model;
    _connections = update.connections;
    _modNamesToColors = _mapFromKeysAndCircularValues(
      _connections.keys,
      _kColors,
    );
    _parametersToColors = _mapFromKeysAndCircularValues(
      _allParametersInModel(_tilerModel),
      _kColors,
    );
  }

  Iterable<ModuleInfo> _flattenTileModel(TileModel tile) => tile == null
      ? []
      : (tile.tiles.expand(_flattenTileModel).toList()..add(tile.content));

  Iterable<String> _allParametersInModel(TilerModel model) =>
      _flattenTileModel(model.root)
          .expand((ModuleInfo content) => content?.parameters ?? <String>[])
          .toSet();

  Map<K, V> _mapFromKeysAndCircularValues<K, V>(
    Iterable<K> keys,
    Iterable<V> values,
  ) =>
      Map.fromIterables(
        keys,
        List.generate(keys.length, (i) => values.elementAt(i % values.length)),
      );

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: _tilerModel.root.isEmpty,
      child: PhysicalModel(
        color: Colors.white,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildStoryTitleBar(),
            ),
            Positioned(
              top: 24,
              left: 4,
              bottom: 4,
              right: 4,
              child: _layoutSuggestionColorModeBuilder(
                (colorForMod) => LayoutPresenter(
                      tilerModel: _tilerModel,
                      connections: _connections,
                      isEditing: _isEditing,
                      focusedMod: _focusedMod,
                      colorForMod: colorForMod,
                      parametersToColors: _parametersToColors,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _tilerModel = cloneTiler(_tilerModel);
      _isEditing = true;
    });
    updateLayoutSuggestionsOverlayVisibility();
  }

  void _endEditing() {
    widget.presenter.requestLayout(_tilerModel);
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _resetTilerModel();
    });
    updateLayoutSuggestionsOverlayVisibility();
  }

  void updateLayoutSuggestionsOverlayVisibility() {
    if (_isEditing && _layoutSuggestionsOverlay == null) {
      _layoutSuggestionsOverlay = OverlayEntry(
        builder: (context) {
          return Positioned(
            left: 0,
            right: 0,
            height: 84,
            bottom: 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 84,
                child: _layoutSuggestionColorModeBuilder(
                  (colorForMod) => LayoutSuggestionsWidget(
                        presenter: widget.presenter,
                        colorForMod: colorForMod,
                        onSelect: (model) {
                          setState(() {
                            _tilerModel = model;
                          });
                        },
                      ),
                ),
              ),
            ),
          );
        },
      );
      print('adding overlay $_layoutSuggestionsOverlay');
      Overlay.of(context).insert(_layoutSuggestionsOverlay);
    }
    if (!_isEditing && _layoutSuggestionsOverlay != null) {
      print('removing overlay $_layoutSuggestionsOverlay');
      _layoutSuggestionsOverlay.remove();
      _layoutSuggestionsOverlay = null;
    }
  }

  Widget _layoutSuggestionColorModeBuilder(
    Widget Function(Color Function(String) colorForMod) builder,
  ) =>
      builder((modName) => _modNamesToColors[modName]);

  Widget _buildTitleBarTextButton(String title, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 12,
              ),
            ),
          ),
        ),
      );

  Widget _buildStoryTitleBar() {
    return Material(
      color: Colors.white,
      child: _isEditing
          ? SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  _buildTitleBarTextButton('Cancel', _cancelEditing),
                  _buildTitleBarTextButton('Done', _endEditing),
                ],
              ),
            )
          : Center(
              child: SizedBox(
                height: 24,
                width: 40,
                child: InkWell(
                  onTap: _startEditing,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 11,
                      child: Tiler(
                        sizerThickness: 0,
                        model: cloneTiler(_tilerModel),
                        chromeBuilder: (BuildContext context, TileModel tile) =>
                            Padding(
                              padding: EdgeInsets.all(0.5),
                              child: Container(color: Colors.black),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

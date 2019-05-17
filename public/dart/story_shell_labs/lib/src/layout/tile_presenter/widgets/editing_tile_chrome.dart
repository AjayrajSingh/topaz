// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:tiler/tiler.dart';
import 'drop_target_widget.dart';

const _kHighlightedBorderWidth = 3.0;
const _kBorderWidth = 1.0;
const _kBorderWidthDiff = _kHighlightedBorderWidth - _kBorderWidth;

const _kTilePlaceholderWhenDragging = DecoratedBox(
  decoration: BoxDecoration(color: Color(0xFFFAFAFA)),
);

/// Chrome for a tiling layout presenter.
class EditingTileChrome extends StatefulWidget {
  /// Constructor for a tiling layout presenter.
  const EditingTileChrome({
    @required this.focusedMod,
    @required this.borderColor,
    @required this.parameterColors,
    @required this.tilerModel,
    @required this.tile,
    @required this.childView,
    @required this.modName,
    @required this.originalSize,
    @required this.editingSize,
  });

  /// Currently focused mod.
  final ValueNotifier focusedMod;

  /// Chrome border color.
  final Color borderColor;

  /// Intent parameter circle colors.
  final Iterable<Color> parameterColors;

  /// The model currently being displayed.
  final TilerModel tilerModel;

  /// The tile being showed on this chrome.
  final TileModel tile;

  /// Content of the chrome.
  final Widget childView;

  /// Surface id of the view displayed here.
  final String modName;

  /// Original size
  final Size originalSize;

  /// Eiditing size
  final Size editingSize;

  @override
  _EditingTileChromeState createState() => _EditingTileChromeState();
}

class _EditingTileChromeState extends State<EditingTileChrome> {
  final _isDragging = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio:
            (widget.originalSize + Offset(_kBorderWidth, _kBorderWidth) * 2.0)
                .aspectRatio,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Draggable(
                onDragStarted: () {
                  widget.focusedMod.value = widget.modName;
                  _isDragging.value = true;
                },
                onDragEnd: (_) {
                  _isDragging.value = false;
                },
                key: Key(widget.modName),
                data: widget.tile,
                feedback: _buildFeedback(),
                childWhenDragging: _kTilePlaceholderWhenDragging,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.borderColor,
                      width: _kBorderWidth,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox.fromSize(
                            size: widget.originalSize,
                            child: widget.childView,
                          ),
                        ),
                      )
                    ]..addAll(_buildSplitTargets(widget.editingSize)),
                  ),
                ),
              ),
            ),
            _buildCornerItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    // to get the offset between the draggable object and the feeback

    // we need the difference between the border width of the original widget and the feedback
    final borderWidthDifference =
        Offset(-_kBorderWidthDiff, -_kBorderWidthDiff);
    // and half the space lost to containing the original size within the editing size (the tile after reducing sizers)
    final boxFitDifference = (widget.editingSize * .5 -
        applyBoxFit(BoxFit.contain, widget.originalSize, widget.editingSize)
                .destination *
            0.5);

    return Transform.translate(
      offset: borderWidthDifference - boxFitDifference,
      child: SizedBox.fromSize(
        size: widget.editingSize +
            Offset(_kBorderWidthDiff, _kBorderWidthDiff) * 2,
        child: Center(
          child: AspectRatio(
            // aspect ratio of original box plus highlighted border
            aspectRatio: (widget.originalSize +
                    Offset(_kHighlightedBorderWidth, _kHighlightedBorderWidth) *
                        2.0)
                .aspectRatio,
            child: Material(
              elevation: 16.0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.borderColor,
                    width: _kHighlightedBorderWidth,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: widget.originalSize,
                    child: widget.childView,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCornerItems() {
    final parameterIndicators = Row(
      children: widget.parameterColors
          .expand((color) => [
                Material(
                  elevation: 4.0,
                  clipBehavior: Clip.antiAlias,
                  shape: CircleBorder(),
                  color: color,
                  child: SizedBox(width: 24, height: 24),
                ),
                SizedBox(width: 8.0),
              ])
          .toList(),
    );

    return Positioned(
      top: 8,
      right: 8,
      child: AnimatedBuilder(
        animation: _isDragging,
        builder: (_, child) =>
            Offstage(offstage: _isDragging.value, child: child),
        child: Row(
          children: <Widget>[
            parameterIndicators,
            Material(
              elevation: 4.0,
              clipBehavior: Clip.antiAlias,
              shape: CircleBorder(),
              child: InkWell(
                onTap: () {
                  widget.tilerModel.remove(widget.tile);
                },
                child: Icon(Icons.close),
              ),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSplitTargets(Size size) => <Widget>[
        _splitTarget(
          nearTile: widget.tile,
          direction: AxisDirection.up,
          parentSizeOnAxis: size.height,
        ),
        _splitTarget(
          nearTile: widget.tile,
          direction: AxisDirection.down,
          parentSizeOnAxis: size.height,
        ),
        _splitTarget(
          nearTile: widget.tile,
          direction: AxisDirection.left,
          parentSizeOnAxis: size.width,
        ),
        _splitTarget(
          nearTile: widget.tile,
          direction: AxisDirection.right,
          parentSizeOnAxis: size.width,
        ),
      ];

  Widget _splitTarget({
    TileModel nearTile,
    AxisDirection direction,
    double parentSizeOnAxis,
  }) =>
      Positioned(
        top: direction == AxisDirection.down ? null : 0,
        bottom: direction == AxisDirection.up ? null : 0,
        left: direction == AxisDirection.right ? null : 0,
        right: direction == AxisDirection.left ? null : 0,
        child: DropTargetWidget(
          onAccept: (tile) {
            widget.tilerModel.remove(tile);
            widget.tilerModel.split(
              content: tile.content,
              direction: direction,
              tile: nearTile,
            );
          },
          onWillAccept: (_) => true,
          axis: axisDirectionToAxis(direction),
          baseSize: 50.0,
          hoverSize: parentSizeOnAxis * .33,
        ),
      );
}

// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:tiler/tiler.dart';
import 'drop_target_widget.dart';

const _kBorderWidth = 2.0;

/// Chrome for a tiling layout presenter.
class EditingTileChrome extends StatefulWidget {
  /// Constructor for a tiling layout presenter.
  const EditingTileChrome({
    @required this.focusedMod,
    @required this.parameterColors,
    @required this.tilerModel,
    @required this.tile,
    @required this.childView,
    @required this.modName,
    @required this.editingSize,
    @required this.willStartDrag,
    @required this.didCancelDrag,
  });

  /// Currently focused mod.
  final ValueNotifier<String> focusedMod;

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

  /// Editing size
  final Size editingSize;

  /// Called before user starts dragging this tile.
  final VoidCallback willStartDrag;

  /// Called after drag was cancelled, either by dropping outside of an accepting target, or because the action was interrupted.
  final VoidCallback didCancelDrag;

  @override
  _EditingTileChromeState createState() => _EditingTileChromeState();
}

class _EditingTileChromeState extends State<EditingTileChrome> {
  // whether this tile is currently being dragged
  final _isDragging = ValueNotifier(false);

  // equal to isDragging, but with 1 frame delay, useful for starting the feedback animation
  final _isDraggingDelayed = ValueNotifier(false);

  // the direction that the tile is being hovered over by another tile, null if nothing is hovering
  final _hoverDirection = ValueNotifier<AxisDirection>(null);

  @override
  void initState() {
    _isDragging.addListener(_isDraggingListener);
    super.initState();
  }

  void _isDraggingListener() async {
    await Future.delayed(Duration(milliseconds: 100));
    _isDraggingDelayed.value = _isDragging.value;
  }

  @override
  void dispose() {
    _isDragging.removeListener(_isDraggingListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Draggable(
      onDragStarted: () {
        widget.willStartDrag();
        widget.focusedMod.value = widget.modName;
        _isDragging.value = true;
        widget.tilerModel.remove(widget.tile);
      },
      onDragEnd: (_) {
        _isDragging.value = false;
      },
      onDraggableCanceled: (_, __) {
        widget.didCancelDrag();
      },
      key: Key(widget.modName),
      data: widget.tile,
      feedback: _buildFeedback(),
      dragAnchor: DragAnchor.pointer,
      childWhenDragging: const Offstage(),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _hoverDirection,
            builder: (_, child) => AnimatedPositioned(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeOutExpo,
                  top: _hoverDirection.value == AxisDirection.up
                      ? widget.editingSize.height * 0.5 + 12
                      : 0,
                  bottom: _hoverDirection.value == AxisDirection.down
                      ? widget.editingSize.height * 0.5 + 12
                      : 0,
                  left: _hoverDirection.value == AxisDirection.left
                      ? widget.editingSize.width * 0.5 + 12
                      : 0,
                  right: _hoverDirection.value == AxisDirection.right
                      ? widget.editingSize.width * 0.5 + 12
                      : 0,
                  child: child,
                ),
            child: AnimatedBuilder(
              animation: widget.focusedMod,
              builder: (_, child) => Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.focusedMod.value == widget.modName
                            ? Color(0xFFFF8BCB)
                            : Colors.black,
                        width: _kBorderWidth,
                      ),
                    ),
                    child: widget.childView,
                  ),
            ),
          ),
        ]..addAll(_buildSplitTargets(widget.editingSize)),
      ),
    );
  }

  Widget _buildFeedback() {
    final contentSize = widget.editingSize;
    return AnimatedBuilder(
      animation: _isDraggingDelayed,
      builder: (_, child) {
        final size = _isDraggingDelayed.value ? contentSize * .5 : contentSize;
        return AnimatedContainer(
          // ease in Quad -> ease out Expo:
          curve: Cubic(0.455, 0.03, 0.0, 1.0),

          // can have a long duration because  it's interactive the whole time
          // and has a strong out easing curve so it spends most of the time at the end
          duration: Duration(milliseconds: 500),

          width: size.width,
          height: size.height,
          transform: Matrix4.translationValues(
            size.width * -.5,
            size.height * -.5,
            0,
          ),
          child: Material(
            color: Color(0xFFFF8BCB),
            elevation: _isDraggingDelayed.value ? 16.0 : 8.5,
            animationDuration: Duration(milliseconds: 500),
            child: child,
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: contentSize.width,
          height: contentSize.height,
          child: Padding(
            padding: const EdgeInsets.all(_kBorderWidth),
            child: widget.childView,
          ),
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
            _hoverDirection.value = null;
            widget.tilerModel.remove(tile);
            widget.tilerModel.split(
              content: tile.content,
              direction: direction,
              tile: nearTile,
            );
          },
          onWillAccept: (tile) {
            if (tile == nearTile) {
              return false;
            }
            _hoverDirection.value = direction;
            return true;
          },
          onLeave: (_) {
            _hoverDirection.value = null;
          },
          axis: axisDirectionToAxis(direction),
          baseSize: 50.0,
          hoverSize: parentSizeOnAxis * .33,
        ),
      );
}

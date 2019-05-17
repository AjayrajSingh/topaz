// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:tiler/tiler.dart';

/// Widget for drag and drop target.
class DropTargetWidget extends StatefulWidget {
  /// COnstructor for the widget.
  const DropTargetWidget({
    @required this.onAccept,
    @required this.onWillAccept,
    @required this.axis,
    @required this.baseSize,
    @required this.hoverSize,
  });

  /// Axis
  final Axis axis;

  /// On drop accept callback
  final DragTargetAccept<TileModel> onAccept;

  /// On drop will accept callback
  final DragTargetWillAccept<TileModel> onWillAccept;

  /// Base size
  final double baseSize;

  /// Hover size
  final double hoverSize;

  @override
  _DropTargetWidgetState createState() => _DropTargetWidgetState();
}

class _DropTargetWidgetState extends State<DropTargetWidget>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return DragTarget<TileModel>(
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final size = hovering ? widget.hoverSize : widget.baseSize;
        final color = hovering ? Colors.purple : Colors.transparent;
        return AnimatedSize(
          duration: Duration(milliseconds: 200),
          curve: Curves.ease,
          vsync: this,
          child: Container(
            width: widget.axis == Axis.horizontal ? size : null,
            height: widget.axis == Axis.vertical ? size : null,
            child: Material(
              elevation: 8,
              color: color,
            ),
          ),
        );
      },
      onWillAccept: widget.onWillAccept,
      onAccept: widget.onAccept,
    );
  }
}

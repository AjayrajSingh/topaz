// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/widgets.dart';

import 'child_view_node.dart';

void _log(String msg) {
  print('[MondrianFlutter] $msg');
}

/// Sets initial offset, used to determine if a surface is being dismissed
typedef void SurfaceHandleOffsetCallback(double offset);

/// Callback for handling surface drag ends,
/// determines if surface is being dismissed
typedef void SurfaceHandleEndCallback(double velocity);

/// Frame for child views
class SurfaceWidget extends StatefulWidget {
  final ChildViewNode _node;
  final SurfaceHandleOffsetCallback _offsetCallback;
  final SurfaceHandleEndCallback _endCallback;

  /// SurfaceWidget
  /// @param _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidget(this._node, this._offsetCallback, this._endCallback, {Key key})
      : super(key: key);

  @override
  SurfaceWidgetState createState() =>
      new SurfaceWidgetState(_node, _offsetCallback, _endCallback);
}

/// Frame for child views
class SurfaceWidgetState extends State<SurfaceWidget> {
  final ChildViewNode _node;

  /// Used for surface dismissal
  final SurfaceHandleOffsetCallback _offsetCallback;

  /// Called when surface drags end to determine surface dismissal
  final SurfaceHandleEndCallback _endCallback;
  double _offset = 0.0;

  /// SurfaceWidgetState
  /// @params _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidgetState(this._node, this._offsetCallback, this._endCallback);

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
        key: new ObjectKey(this),
        onHorizontalDragStart: (DragStartDetails details) {
          _log('Drag started.');
          _offset = 0.0;
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (details.primaryDelta != 0.0) {
            _offset += details.primaryDelta;
            _offsetCallback(_offset);
          }
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          _log('Drag ended.');
          _endCallback(details.primaryVelocity);
        },
        behavior: HitTestBehavior.opaque,
        child: new Container(
          padding: const EdgeInsets.only(right: 20.0, left: 20.0),
          child: new ChildView(connection: _node.connection),
        ));
  }
}

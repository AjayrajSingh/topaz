// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/widgets.dart';

import 'child_view_node.dart';

/// Sets initial offset, used to determine if a surface is being dismissed
typedef void SurfaceHandleOffsetCallback(double offset);

/// Callback for handling surface drag ends,
/// determines if surface is being dismissed
typedef void SurfaceHandleEndCallback(double velocity);

/// Frame for child views
class SurfaceWidget extends StatefulWidget {
  final ChildViewNode _node;

  /// SurfaceWidget
  /// @param _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidget(this._node, {Key key}) : super(key: key);

  @override
  SurfaceWidgetState createState() => new SurfaceWidgetState(_node);
}

/// Frame for child views
class SurfaceWidgetState extends State<SurfaceWidget> {
  final ChildViewNode _node;

  /// SurfaceWidgetState
  /// @params _node The ChildViewNode
  SurfaceWidgetState(
    this._node,
  );

  @override
  Widget build(BuildContext context) {
    return new Container(
        margin: const EdgeInsets.all(2.0),
        padding: const EdgeInsets.all(20.0),
        color: const Color(0xFFFFFFFF),
        child: new ChildView(connection: _node.connection));
  }
}

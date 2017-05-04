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
  /// The ChildView node this surface is embeding
  final ChildViewNode node;

  /// If true then ChildView hit tests will go through
  final bool interactable;

  /// SurfaceWidget
  /// @param _node The ChildViewNode
  /// @param _offsetCallback The callback used to capture initial offset
  /// @param _endCallback The callback to handle determine surface dismissal
  SurfaceWidget(this.node, {Key key, this.interactable: true})
      : super(key: key);

  @override
  SurfaceWidgetState createState() => new SurfaceWidgetState();
}

/// Frame for child views
class SurfaceWidgetState extends State<SurfaceWidget> {
  @override
  Widget build(BuildContext context) {
    return new Container(
        margin: const EdgeInsets.all(2.0),
        padding: const EdgeInsets.all(20.0),
        color: const Color(0xFFFFFFFF),
        child: new ChildView(
            connection: widget.node.connection,
            hitTestable: widget.interactable));
  }
}

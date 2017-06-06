// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'window/model.dart';
import 'window/window.dart';

/// Displays a set of windows.
class WindowPlaygroundWidget extends StatefulWidget {
  @override
  _PlaygroundState createState() => new _PlaygroundState();
}

class _PlaygroundState extends State<WindowPlaygroundWidget> {
  final WindowsData _windows = new WindowsData()..add()..add();
  final Map<WindowId, GlobalKey<WindowState>> _windowKeys =
      new Map<WindowId, GlobalKey<WindowState>>();
  final FocusScopeNode _focusNode = new FocusScopeNode();

  @override
  void dispose() {
    _focusNode.detach();
    super.dispose();
  }

  /// Builds the widget representations of the current windows.
  List<Widget> _buildWindows(
      WindowsData model, double maxWidth, double maxHeight) {
    // Remove keys that are no longer useful.
    List<WindowId> obsoleteIds = new List<WindowId>();
    _windowKeys.keys.forEach((WindowId id) {
      if (!model.windows.any((WindowData window) => window.id == id)) {
        obsoleteIds.add(id);
      }
    });
    obsoleteIds.forEach((WindowId id) => _windowKeys.remove(id));
    return model.windows
        .map((WindowData window) => new ScopedModel<WindowData>(
              model: window,
              child: new Window(
                key: _windowKeys.putIfAbsent(
                  window.id,
                  () => new GlobalKey<WindowState>(),
                ),
                initialPosition: new Offset(maxWidth / 4, maxHeight / 4),
                initialSize: new Size(maxWidth / 2, maxHeight / 2),
                onWindowInteraction: () => model.moveToFront(window),
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) => new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          return new Overlay(
            initialEntries: <OverlayEntry>[
              new OverlayEntry(
                builder: (BuildContext context) => new FocusScope(
                      node: _focusNode,
                      autofocus: true,
                      child: new ScopedModel<WindowsData>(
                        model: _windows,
                        child: new ScopedModelDescendant<WindowsData>(
                          builder: (
                            BuildContext context,
                            Widget child,
                            WindowsData model,
                          ) =>
                              new Stack(
                                children: <Widget>[
                                  new DragTarget<TabId>(
                                    builder: (BuildContext context,
                                            List<TabId> candidateData,
                                            List<dynamic> rejectedData) =>
                                        new Container(),
                                    onAccept: (TabId id) => model.add(id: id),
                                  )
                                ]..addAll(_buildWindows(model, width, height)),
                              ),
                        ),
                      ),
                    ),
              ),
            ],
          );
        },
      );
}

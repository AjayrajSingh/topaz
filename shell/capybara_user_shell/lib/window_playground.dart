// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'window/window.dart';

/// Displays a set of windows.
class WindowPlaygroundWidget extends StatefulWidget {
  @override
  _PlaygroundState createState() => new _PlaygroundState();
}

class _PlaygroundState extends State<WindowPlaygroundWidget> {
  final List<GlobalKey<WindowState>> _windows = <GlobalKey<WindowState>>[];

  @override
  void initState() {
    super.initState();
    _addWindow();
    _addWindow();
  }

  /// Adds a new window to this playground.
  void _addWindow() {
    setState(() {
      _windows.add(new GlobalKey<WindowState>());
    });
  }

  /// Focuses the window with the given key if it exists.
  void _focusWindow(Key key) {
    setState(() {
      if (_windows.isEmpty || !_windows.contains(key) || _windows.last == key) {
        return;
      }
      _windows.remove(key);
      _windows.add(key);
    });
  }

  /// Builds the widget representations of the current windows.
  List<Widget> _buildWindows() => _windows
      .map((Key key) => new Window(
            key: key,
            onWindowInteraction: () => _focusWindow(key),
          ))
      .toList();

  @override
  Widget build(BuildContext context) => new Overlay(
        initialEntries: <OverlayEntry>[
          new OverlayEntry(
            builder: (BuildContext context) => new Stack(
                  children: _buildWindows(),
                ),
          ),
        ],
      );
}

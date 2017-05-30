// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'tab_data.dart';

/// A window container.
class Window extends StatefulWidget {
  @override
  _WindowState createState() => new _WindowState();
}

class _WindowState extends State<Window> {
  final List<TabData> _tabs = <TabData>[];

  _WindowState() {
    _tabs.add(new TabData(const Color(0xff008744))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData(const Color(0xff0057e7))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData(const Color(0xffd62d20))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData(const Color(0xffffa700))
      ..onOwnerChanged = _onTabOwnerChanged);
  }

  /// Called when a new tab was added to this window.
  void _onTabAdded(TabData data) {
    setState(() {
      data.onOwnerChanged?.call(data);
      _tabs.add(data..onOwnerChanged = _onTabOwnerChanged);
    });
  }

  /// Called when a tab previously owned by this window was moved to a different
  /// window.
  void _onTabOwnerChanged(TabData data) {
    setState(() {
      _tabs.remove(data);
    });
  }

  @override
  Widget build(BuildContext context) => new Container(
        padding: const EdgeInsets.all(12.0),
        decoration: const BoxDecoration(
          color: const Color(0xffbcbcbc),
        ),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            new DragTarget<TabData>(
              builder: (BuildContext context, List<TabData> candidateData,
                      List<dynamic> rejectedData) =>
                  new Container(
                    height: 60.0,
                    padding: const EdgeInsets.all(10.0),
                    decoration: candidateData.isEmpty
                        ? const BoxDecoration(color: const Color(0x003377bb))
                        : const BoxDecoration(color: const Color(0x33111111)),
                    child: new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _tabs
                          .map(
                            (TabData data) => new Draggable<TabData>(
                                  child: new Container(
                                    width: 50.0,
                                    decoration:
                                        new BoxDecoration(color: data.color),
                                  ),
                                  childWhenDragging: new Container(),
                                  feedback: new Container(
                                    width: 50.0,
                                    height: 40.0,
                                    decoration:
                                        new BoxDecoration(color: data.color),
                                  ),
                                  data: data,
                                ),
                          )
                          .toList(),
                    ),
                  ),
              onAccept: _onTabAdded,
            ),
            new Center(child: new Text('I am a window')),
          ],
        ),
      );
}

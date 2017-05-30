// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'tab_data.dart';

/// A window container.
class Window extends StatefulWidget {
  /// The window's initial position within its parent.
  final Offset initialPosition;

  /// Constructor.
  Window({this.initialPosition: Offset.zero});

  @override
  _WindowState createState() => new _WindowState();
}

class _WindowState extends State<Window> {
  final List<TabData> _tabs = <TabData>[];
  Offset _position = Offset.zero;
  Size _size = new Size(500.0, 200.0);

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

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
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
  Widget build(BuildContext context) => new Positioned(
        left: _position.dx,
        top: _position.dy,
        child: new Container(
          width: _size.width,
          height: _size.height,
          padding: const EdgeInsets.all(8.0),
          decoration: new BoxDecoration(
            color: const Color(0xffbcbcbc),
            borderRadius: new BorderRadius.circular(4.0),
          ),
          child: new Stack(
            children: <Widget>[
              new Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  new GestureDetector(
                    onPanUpdate: (DragUpdateDetails details) {
                      setState(() {
                        _position += details.delta;
                      });
                    },
                    child: new DragTarget<TabData>(
                      builder: (BuildContext context,
                              List<TabData> candidateData,
                              List<dynamic> rejectedData) =>
                          new Container(
                            height: 60.0,
                            padding: const EdgeInsets.all(10.0),
                            decoration: candidateData.isEmpty
                                ? const BoxDecoration(
                                    color: const Color(0x003377bb))
                                : const BoxDecoration(
                                    color: const Color(0x33111111)),
                            child: new Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _tabs
                                  .map(
                                    (TabData data) => new Draggable<TabData>(
                                          child: new Container(
                                            width: 50.0,
                                            decoration: new BoxDecoration(
                                              color: data.color,
                                            ),
                                          ),
                                          childWhenDragging: new Container(),
                                          feedback: new Container(
                                            width: 50.0,
                                            height: 40.0,
                                            decoration: new BoxDecoration(
                                              color: data.color,
                                            ),
                                          ),
                                          data: data,
                                        ),
                                  )
                                  .toList(),
                            ),
                          ),
                      onAccept: _onTabAdded,
                    ),
                  ),
                  new Center(child: new Text('I am a window')),
                ],
              ),
              new Positioned(
                right: 0.0,
                bottom: 0.0,
                child: new GestureDetector(
                  onPanUpdate: (DragUpdateDetails details) {
                    setState(() {
                      _size += details.delta;
                    });
                  },
                  child: new Container(
                    width: 20.0,
                    height: 20.0,
                    decoration: const BoxDecoration(
                      color: const Color(0xffffffff),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

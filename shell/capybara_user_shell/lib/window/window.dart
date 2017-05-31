// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'tab_data.dart';

/// Signature of window interaction callbacks.
typedef void WindowInteractionCallback();

/// A window container.
class Window extends StatefulWidget {
  /// Called when the user started interacting with this window.
  final WindowInteractionCallback onWindowInteraction;

  /// Constructor.
  Window({Key key, this.onWindowInteraction}) : super(key: key);

  @override
  WindowState createState() => new WindowState();
}

/// Holds the state of a Window widget.
class WindowState extends State<Window> {
  final List<TabData> _tabs = <TabData>[];
  TabData _selectedTab;
  Offset _position = Offset.zero;
  Size _size = new Size(500.0, 200.0);

  /// Constructor.
  WindowState() {
    _tabs.add(new TabData('Alpha', const Color(0xff008744))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData('Beta', const Color(0xff0057e7))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData('Gamma', const Color(0xffd62d20))
      ..onOwnerChanged = _onTabOwnerChanged);
    _tabs.add(new TabData('Delta', const Color(0xffffa700))
      ..onOwnerChanged = _onTabOwnerChanged);
    _selectedTab = _tabs[0];
  }

  /// Called when a new tab was added to this window.
  void _onTabAdded(TabData data) {
    setState(() {
      if (_tabs.contains(data)) {
        // Just relocate the tab to the end.
        _tabs.remove(data);
        _tabs.add(data);
      } else {
        data.onOwnerChanged?.call(data);
        _tabs.add(data..onOwnerChanged = _onTabOwnerChanged);
      }
      _selectedTab = data;
    });
  }

  /// Called when a tab previously owned by this window was moved to a different
  /// window.
  void _onTabOwnerChanged(TabData data) {
    setState(() {
      _tabs.remove(data);
      if (data == _selectedTab) {
        _selectedTab = _tabs.isEmpty ? null : _tabs.last;
      }
    });
  }

  /// Registers that some interaction has occurred with the present window.
  void _registerInteraction() => widget.onWindowInteraction?.call();

  /// Constructs the visual representation of a tab.
  Widget _buildTab(TabData data) {
    final Widget visual = new Container(
      width: 80.0,
      height: 40.0,
      padding: const EdgeInsets.all(4.0),
      child: new Container(
          decoration: new BoxDecoration(
            color: data == _selectedTab ? const Color(0xff777777) : null,
            border: new Border.all(color: data.color),
          ),
          child: new Center(
            child: new Text(data.name, overflow: TextOverflow.ellipsis),
          )),
    );
    return new GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = data;
        });
      },
      child: new Draggable<TabData>(
        child: visual,
        childWhenDragging: new Container(),
        feedback: visual,
        data: data,
        onDraggableCanceled: (_, __) => _registerInteraction(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => new Positioned(
        left: _position.dx,
        top: _position.dy,
        child: new GestureDetector(
          onTapDown: (_) => _registerInteraction(),
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
                              height: 64.0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                                horizontal: 8.0,
                              ),
                              color: candidateData.isEmpty
                                  ? const Color(0x003377bb)
                                  : const Color(0x33111111),
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _tabs.map(_buildTab).toList(),
                              ),
                            ),
                        onWillAccept: (_) {
                          _registerInteraction();
                          return true;
                        },
                        onAccept: _onTabAdded,
                      ),
                    ),
                    new Flexible(
                      child: new Container(
                        color: _selectedTab != null ? _selectedTab.color : null,
                      ),
                    ),
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
                      color: const Color(0xffcccccc),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

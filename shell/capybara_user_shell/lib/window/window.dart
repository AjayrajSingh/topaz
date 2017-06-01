// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'model.dart';

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
  /// The currently selected tab.
  TabId _selectedTabId;

  /// The tab currently being dragged.
  TabId _draggedTabId;

  /// The window's position.
  Offset _position = Offset.zero;

  /// The window's size.
  Size _size = new Size(500.0, 200.0);

  /// Called when a new tab was dropped on this window.
  void _onTabDropped(WindowData window, TabId id) {
    if (window.claim(id)) {
      setState(() => _selectedTabId = id);
    }
  }

  /// Registers that some interaction has occurred with the present window.
  void _registerInteraction() => widget.onWindowInteraction?.call();

  /// Constructs the visual representation of a tab.
  Widget _buildTab({TabData tab, bool selected}) {
    Widget buildVisual(bool withSelection) => new Container(
          width: 80.0,
          height: 40.0,
          padding: const EdgeInsets.all(4.0),
          child: new Container(
              decoration: new BoxDecoration(
                color: withSelection ? const Color(0xff777777) : null,
                border: new Border.all(color: tab.color),
              ),
              child: new Center(
                child: new Text(tab.name, overflow: TextOverflow.ellipsis),
              )),
        );
    return new GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabId = tab.id;
        });
      },
      child: new Draggable<TabId>(
        child: buildVisual(selected),
        childWhenDragging: new Container(),
        feedback: buildVisual(false),
        data: tab.id,
        onDragStarted: () => setState(() {
              _draggedTabId = tab.id;
            }),
        onDraggableCanceled: (_, __) {
          _registerInteraction();
          setState(() {
            _draggedTabId = null;
          });
        },
        onDragCompleted: () => setState(() {
              _draggedTabId = null;
            }),
      ),
    );
  }

  /// Returns the selected tab, accounting for drag'n'drop operations.
  TabData _getCurrentSelection(WindowData model) {
    if (!model.has(_selectedTabId)) {
      // Default to the last tab if there's no valid selection.
      _selectedTabId = model.tabs.isNotEmpty ? model.tabs.last.id : null;
    }
    // If the selected tab is currently being dragged, temporarily select
    // another one.
    return _draggedTabId != _selectedTabId
        ? (_selectedTabId != null ? model.find(_selectedTabId) : null)
        : model.tabs.lastWhere((TabData tab) => tab.id != _draggedTabId,
            orElse: () => null);
  }

  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<WindowData>(
        builder: (
          BuildContext context,
          Widget child,
          WindowData model,
        ) {
          if (model.tabs.length == 1 && model.tabs[0].id == _draggedTabId) {
            // If the lone tab is being dragged, hide this window.
            return new Container();
          }
          final TabData selectedTab = _getCurrentSelection(model);
          return new Positioned(
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
                          child: new DragTarget<TabId>(
                            builder: (BuildContext context,
                                    List<TabId> candidateData,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: model.tabs
                                        .map((TabData tab) => _buildTab(
                                            tab: tab,
                                            selected: tab == selectedTab))
                                        .toList(),
                                  ),
                                ),
                            onWillAccept: (_) {
                              _registerInteraction();
                              return true;
                            },
                            onAccept: (TabId id) => _onTabDropped(model, id),
                          ),
                        ),
                        new Expanded(
                          child: new Container(
                            color: selectedTab?.color,
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
        },
      );
}

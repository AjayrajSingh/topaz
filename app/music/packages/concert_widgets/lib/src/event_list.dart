// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'event_list_item.dart';
import 'typedefs.dart';

const double _kMinHeaderHeight = 160.0;
const double _kLogoSize = 48.0;
const double _kEventGridMinWidth = 300.0;
const double _kEventGridAspectRatio = 1.2;
const double _kEventListHeight = 96.0;

/// UI Widget that represents a list of [Event]s
class EventList extends StatelessWidget {
  /// [Event]s to list out
  final List<Event> events;

  /// The event that is selected
  final Event selectedEvent;

  /// Callback for when an event is selected
  final EventActionCallback onSelect;

  static final DateFormat _kMonthFormat = new DateFormat('MMMM y');

  static final _EventListGridDelegate _eventListGridDelegate =
      new _EventListGridDelegate();

  /// Constructor
  const EventList({
    Key key,
    @required this.events,
    this.selectedEvent,
    this.onSelect,
  })
      : assert(events != null),
        super(key: key);

  String get _listTitle =>
      'Concert Guide  -  ${_kMonthFormat.format(new DateTime.now())}';

  Widget _buildHeader() {
    return new Container(
      constraints: new BoxConstraints(
        minHeight: _kMinHeaderHeight,
      ),
      child: new AspectRatio(
        aspectRatio: 4.5,
        child: new Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: const AssetImage(
                'packages/concert_widgets/res/concert_bg.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: new Center(
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Container(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: new Image.asset(
                    'packages/concert_widgets/res/plat_logo.png',
                    height: _kLogoSize,
                    width: _kLogoSize,
                  ),
                ),
                new Text(
                  _listTitle,
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        bool showGridLayout = constraints.maxWidth >= _kEventGridMinWidth * 2;
        return new CustomScrollView(
          slivers: <Widget>[
            new SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            new SliverPadding(
              padding: showGridLayout
                  ? const EdgeInsets.all(16.0)
                  : const EdgeInsets.all(0.0),
              sliver: new SliverGrid(
                gridDelegate: _eventListGridDelegate,
                delegate: new SliverChildListDelegate(
                  events
                      .map((Event event) => new EventListItem(
                            event: event,
                            onSelect: onSelect,
                            isSelected: event == selectedEvent,
                            showGridLayout: showGridLayout,
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grid delegate for Event Grid
class _EventListGridDelegate extends SliverGridDelegate {
  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final int crossAxisCount =
        max((constraints.crossAxisExtent / _kEventGridMinWidth).floor(), 1);
    final double childCrossAxisExtent =
        constraints.crossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = crossAxisCount == 1
        ? _kEventListHeight
        : childCrossAxisExtent / _kEventGridAspectRatio;
    return new SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_EventListGridDelegate oldDelegate) {
    return false;
  }
}

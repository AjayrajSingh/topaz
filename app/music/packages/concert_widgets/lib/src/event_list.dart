// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'concert_guide_header.dart';
import 'event_list_item.dart';
import 'loading_status.dart';
import 'typedefs.dart';

const double _kMinHeaderHeight = 160.0;
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

  /// Loading status of concert list
  final LoadingStatus loadingStatus;

  static final _EventListGridDelegate _eventListGridDelegate =
      new _EventListGridDelegate();

  /// Constructor
  const EventList({
    Key key,
    this.events,
    this.selectedEvent,
    this.onSelect,
    this.loadingStatus: LoadingStatus.inProgress,
  })
      : super(key: key);

  Widget _buildHeader() {
    return new Container(
      constraints: new BoxConstraints(
        minHeight: _kMinHeaderHeight,
      ),
      child: new AspectRatio(
        aspectRatio: 4.5,
        child: new ConcertGuideHeader(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Event> eventList =
        events != null && loadingStatus == LoadingStatus.completed
            ? events
            : <Event>[
                null,
                null,
                null,
                null,
                null,
                null,
              ];
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
                  eventList
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

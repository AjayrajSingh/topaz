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
const int _kItemsPerPage = 3;

/// UI Widget that represents a pageable list of [Event]s
class PageableEventList extends StatelessWidget {
  /// Constructor
  const PageableEventList({
    Key key,
    this.events,
    this.selectedEvent,
    this.onSelect,
    this.onPageChanged,
    this.loadingStatus: LoadingStatus.inProgress,
  })
      : super(key: key);

  /// [Event]s to list out
  final List<Event> events;

  /// The event that is selected
  final Event selectedEvent;

  /// Callback for when an event is selected
  final EventActionCallback onSelect;

  /// Called when the page changes.
  final ValueChanged<int> onPageChanged;

  /// Loading status of pageable concert list
  final LoadingStatus loadingStatus;

  List<Event> get _events {
    if (events != null && loadingStatus == LoadingStatus.completed) {
      return events;
    } else {
      return <Event>[null, null, null];
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        new Container(
          constraints: new BoxConstraints(
            minHeight: _kMinHeaderHeight,
          ),
          child: new AspectRatio(
            aspectRatio: 4.5,
            child: new ConcertGuideHeader(),
          ),
        ),
        new Expanded(
          child: _buildPageableList(),
        ),
      ],
    );
  }

  Widget _buildPage({
    int pageIndex,
    int itemsPerPage,
    Axis axis,
    double padding,
  }) {
    int startIndex = pageIndex * itemsPerPage;
    int endIndex = min(pageIndex * itemsPerPage + itemsPerPage, _events.length);
    List<Widget> children = _events
        .sublist(startIndex, endIndex)
        .map((Event event) => new Expanded(
              child: new Container(
                padding: new EdgeInsets.all(padding),
                child: new EventListItem(
                  event: event,
                  onSelect: onSelect,
                  isSelected: event == selectedEvent,
                  showGridLayout: axis == Axis.horizontal,
                ),
              ),
            ))
        .toList();
    if (children.length < itemsPerPage) {
      // Add empty spacer if the page isn't filled up with itemss
      children.add(new Expanded(
        flex: itemsPerPage - children.length,
        child: new Container(),
      ));
    }
    return new Container(
      color: Colors.white,
      padding: new EdgeInsets.all(padding),
      child: axis == Axis.horizontal
          ? new Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            )
          : new Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
    );
  }

  Widget _buildPageableList() {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        Axis axis =
            constraints.maxWidth < 500.0 ? Axis.vertical : Axis.horizontal;
        int pageCount = (_events.length / _kItemsPerPage).ceil();
        double minBoundsSize = min(constraints.maxHeight, constraints.maxWidth);

        return new PageView.builder(
          scrollDirection: axis,
          itemCount: pageCount,
          onPageChanged: onPageChanged,
          itemBuilder: (BuildContext context, int index) => _buildPage(
                pageIndex: index,
                itemsPerPage: _kItemsPerPage,
                axis: axis,
                padding: axis == Axis.horizontal ? minBoundsSize / 30.0 : 8.0,
              ),
        );
      },
    );
  }
}

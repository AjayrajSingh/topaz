// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'event_list_item.dart';
import 'typedefs.dart';

const double _kHeaderHeight = 160.0;
const double _kLogoSize = 48.0;

/// UI Widget that represents a list of [Event]s
class EventList extends StatelessWidget {
  /// [Event]s to list out
  final List<Event> events;

  /// The event that is selected
  final Event selectedEvent;

  /// Callback for when an event is selected
  final EventActionCallback onSelect;

  static final DateFormat _kMonthFormat = new DateFormat('MMMM y');

  /// Constructor
  EventList({
    Key key,
    @required this.events,
    this.selectedEvent,
    this.onSelect,
  })
      : super(key: key) {
    assert(events != null);
  }

  String get _listTitle =>
      'Concert Guide  -  ${_kMonthFormat.format(new DateTime.now())}';

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
      new Container(
        height: _kHeaderHeight,
        decoration: new BoxDecoration(
          image: new DecorationImage(
            image: new AssetImage(
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
    ];

    children.addAll(events
        .map((Event event) => new EventListItem(
              event: event,
              onSelect: onSelect,
              isSelected: event == selectedEvent,
            ))
        .toList());

    return new Column(
      children: children,
    );
  }
}

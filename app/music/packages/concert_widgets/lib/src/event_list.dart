// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'event_list_item.dart';
import 'typedefs.dart';

/// UI Widget that represents a list of [Event]s
class EventList extends StatelessWidget {
  /// [Event]s to list out
  final List<Event> events;

  /// The event that is selected
  final Event selectedEvent;

  /// Callback for when an event is selected
  final EventActionCallback onSelect;

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

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: events
          .map((Event event) => new EventListItem(
                event: event,
                onSelect: onSelect,
                isSelected: event == selectedEvent,
              ))
          .toList(),
    );
  }
}

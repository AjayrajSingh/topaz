// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'fallback_image.dart';
import 'typedefs.dart';

const double _kListHeight = 64.0;

/// UI Widget that represents a list item for an [Event]
class EventListItem extends StatelessWidget {
  /// [Event] to represent
  final Event event;

  /// Callback for when this event is selected
  final EventActionCallback onSelect;

  static final DateFormat _dateFormat = new DateFormat('MMM d');

  /// True if this [EventListItem] is selected
  final bool isSelected;

  /// If true, show grid layout for this item.
  final bool showGridLayout;

  /// Constructor
  const EventListItem(
      {Key key,
      bool isSelected,
      @required this.event,
      this.onSelect,
      this.showGridLayout: false})
      : assert(event != null),
        assert(showGridLayout != null),
        isSelected = isSelected ?? false,
        super(key: key);

  String get _eventImage => event.performances.isNotEmpty
      ? event.performances.first.artist?.imageUrl
      : null;

  String get _readableDate =>
      event.date != null ? _dateFormat.format(event.date) : '';

  String get _eventTitle => event.performances.isNotEmpty
      ? event.performances.first.artist?.name ?? event.name ?? ''
      : event.name ?? '';

  Widget _buildTextSection() {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        new Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          child: new Text(
            _readableDate.toUpperCase(),
            style: new TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
              fontSize: 12.0,
            ),
          ),
        ),
        new Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          child: new Text(
            _eventTitle,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: new TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        new Text(
          event.venue?.name ?? '',
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: new TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    Widget image = new ClipRRect(
      borderRadius: new BorderRadius.circular(8.0),
      child: new FallbackImage(
        url: _eventImage,
      ),
    );

    if (showGridLayout) {
      return new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Expanded(child: image),
          new Container(
            padding: const EdgeInsets.only(top: 16.0),
            child: _buildTextSection(),
          ),
        ],
      );
    } else {
      return new Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(right: 16.0),
            child: new Container(
              height: _kListHeight,
              width: _kListHeight,
              child: image,
            ),
          ),
          new Expanded(
            child: _buildTextSection(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Material(
      color: isSelected ? Colors.grey[200] : Colors.white,
      child: new InkWell(
        onTap: () => onSelect?.call(event),
        child: new Container(
          padding: const EdgeInsets.all(16.0),
          child: _buildMainContent(),
        ),
      ),
    );
  }
}

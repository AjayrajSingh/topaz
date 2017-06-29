// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'fallback_image.dart';

const double _kHeroImageHeight = 240.0;
const double _kLogoSize = 32.0;
const double _kLineupAvatarSize = 48.0;

final TextStyle _kVenueFontStyle = new TextStyle(
  fontSize: 16.0,
  height: 1.5,
);

/// UI widget that represents an entire concert page
class EventPage extends StatelessWidget {
  /// The [Event] that this page renders
  final Event event;

  /// Callback for when the user taps the buy button
  final VoidCallback onTapBuy;

  static final DateFormat _dateFormat = new DateFormat('EEEE, d LLLL y');

  static final DateFormat _timeFormat = new DateFormat('h:mm aaa');

  /// Constructor
  EventPage({
    Key key,
    this.onTapBuy,
    @required this.event,
  })
      : super(key: key) {
    assert(event != null);
  }

  String get _readableDate {
    String date = _dateFormat.format(event.date);
    // Some events do not include the start time
    if (event.startTime != null) {
      date += ' ${_timeFormat.format(event.startTime)}';
    }
    return date;
  }

  Widget _buildVenueSection() {
    List<Widget> children = <Widget>[
      new Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: new Text(
          'Venue',
          style: new TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 18.0,
          ),
        ),
      ),
    ];
    if (event.venue.name != null) {
      children.add(new Text(event.venue.name, style: _kVenueFontStyle));
    }
    if (event.venue.street != null) {
      children.add(new Text(event.venue.street, style: _kVenueFontStyle));
    }
    if (event.venue.city?.name != null ||
        event.venue.city?.country != null ||
        event.venue.zip != null) {
      children.add(new Text(
        '${event.venue.city?.name + ', ' ?? ''}${event.venue.city?.country ?? ''} ${ event.venue.zip ?? ''}',
        style: _kVenueFontStyle,
      ));
    }
    if (event.venue.phoneNumber != null) {
      children.add(new Text(event.venue.phoneNumber, style: _kVenueFontStyle));
    }
    return new Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildOtherPerformers() {
    List<Widget> artistImages = <Widget>[];
    for (int i = 1; i < event.performances.length; i++) {
      Artist artist = event.performances[i].artist;
      artistImages.add(new Container(
        margin: const EdgeInsets.only(right: 8.0),
        child: new ClipOval(
          child: new FallbackImage(
            height: _kLineupAvatarSize,
            width: _kLineupAvatarSize,
            url: artist.imageUrl,
          ),
        ),
      ));
    }

    return new Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: new Text(
            'Lineup',
            style: new TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: artistImages,
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    List<Widget> children = <Widget>[];

    if (event.venue != null) {
      children.add(new Expanded(
        child: _buildVenueSection(),
      ));
    }

    if (event.performances.length > 1) {
      children.add(new Expanded(
        child: _buildOtherPerformers(),
      ));
    }

    return new Container(
      padding: const EdgeInsets.all(16.0),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
      new Container(
        margin: const EdgeInsets.only(bottom: 24.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            new Expanded(
              child: new Text(
                event.performances.isNotEmpty
                    ? event.performances.first.artist?.name ?? ''
                    : '',
                style: new TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            new Image.asset(
              'packages/concert_widgets/res/myseat.png',
              height: _kLogoSize,
              width: _kLogoSize,
            ),
          ],
        ),
      ),
      new FallbackImage(
        url: event.performances.isNotEmpty
            ? event.performances.first.artist?.imageUrl
            : null,
        height: _kHeroImageHeight,
      ),
      new Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.only(bottom: 16.0),
        decoration: new BoxDecoration(
          color: Colors.grey[200],
          borderRadius: new BorderRadius.vertical(
            bottom: new Radius.circular(8.0),
          ),
        ),
        child: new Row(
          children: <Widget>[
            new Expanded(
              child: new Text(
                _readableDate,
                style: new TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            new RaisedButton(
              child: new Icon(
                Icons.shopping_cart,
                color: Colors.white,
              ),
              onPressed: () => onTapBuy?.call(),
              color: Colors.pink[500],
            ),
          ],
        ),
      ),
      _buildDetailsSection(),
    ];

    return new Container(
      padding: const EdgeInsets.all(32.0),
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

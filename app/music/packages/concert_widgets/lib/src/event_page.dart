// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:concert_models/concert_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'fallback_image.dart';
import 'loading_status.dart';
import 'text_placeholder.dart';

const double _kHeroImageHeight = 240.0;
const double _kLogoSize = 32.0;
const double _kLineupAvatarSize = 48.0;

final TextStyle _kVenueTextStyle = const TextStyle(
  fontSize: 16.0,
  height: 1.5,
);

final TextStyle _kEventTextStyle = const TextStyle(
  fontSize: 34.0,
  fontWeight: FontWeight.w500,
  height: 1.2,
);

final TextStyle _kDateTextStyle = const TextStyle(
  fontSize: 20.0,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

/// UI widget that represents an entire concert page
class EventPage extends StatelessWidget {
  /// The [Event] that this page renders
  final Event event;

  /// Callback for when the user taps the buy button
  final VoidCallback onTapBuy;

  /// Loading status of event page
  final LoadingStatus loadingStatus;

  static final DateFormat _dateFormat = new DateFormat('EEEE, d LLLL y');

  static final DateFormat _timeFormat = new DateFormat('h:mm aaa');

  /// Constructor
  const EventPage({
    Key key,
    this.onTapBuy,
    this.event,
    this.loadingStatus: LoadingStatus.inProgress,
  })
      : super(key: key);

  String get _readableDate {
    String date = _dateFormat.format(event.date);
    // Some events do not include the start time
    if (event.startTime != null) {
      date = '$date ${_timeFormat.format(event.startTime)}';
    }
    return date;
  }

  bool get _showPlaceholder =>
      event == null || loadingStatus != LoadingStatus.completed;

  Widget _buildVenueSection() {
    List<Widget> children = <Widget>[
      new Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: const Text(
          'Venue',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18.0,
          ),
        ),
      ),
    ];

    if (event.venue.name != null) {
      children.add(new Text(event.venue.name, style: _kVenueTextStyle));
    }
    if (event.venue.street != null) {
      children.add(new Text(event.venue.street, style: _kVenueTextStyle));
    }
    if (event.venue.city?.name != null ||
        event.venue.city?.country != null ||
        event.venue.zip != null) {
      String city =
          event.venue.city?.name != null ? '${event.venue.city.name}, ' : '';
      children.add(new Text(
        '$city${event.venue.city?.country ?? ''} ${ event.venue.zip ?? ''}',
        style: _kVenueTextStyle,
      ));
    }
    if (event.venue.phoneNumber != null) {
      children.add(new Text(event.venue.phoneNumber, style: _kVenueTextStyle));
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
          child: const Text(
            'Lineup',
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
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

    if (!_showPlaceholder && event.venue != null) {
      children.add(new Expanded(
        child: _buildVenueSection(),
      ));
    }

    if (!_showPlaceholder && event.performances.length > 1) {
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
              child: _showPlaceholder
                  ? new Container(
                      padding: const EdgeInsets.only(right: 100.0),
                      child: new TextPlaceholder(
                        style: _kEventTextStyle,
                      ),
                    )
                  : new Text(
                      event.performances.isNotEmpty
                          ? event.performances.first.artist?.name ?? ''
                          : '',
                      style: _kEventTextStyle,
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
        url: !_showPlaceholder && event.performances.isNotEmpty
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
            bottom: const Radius.circular(8.0),
          ),
        ),
        child: new Row(
          children: <Widget>[
            new Expanded(
              child: _showPlaceholder
                  ? new Container(
                      padding: const EdgeInsets.only(right: 100.0),
                      child: new TextPlaceholder(style: _kDateTextStyle),
                    )
                  : new Text(
                      _readableDate,
                      style: _kDateTextStyle,
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

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'RobotoSlab'),
      child: new Container(
        padding: const EdgeInsets.all(32.0),
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

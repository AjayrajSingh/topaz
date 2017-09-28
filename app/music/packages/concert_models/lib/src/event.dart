// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'artist.dart';
import 'venue.dart';

/// Model representing a Songkick event
///
/// See: http://www.songkick.com/developer/events-details
class Event {
  /// Name of event
  final String name;

  /// Type of event
  ///
  /// ex. Concert, Festival...
  final String type;

  /// Time that this event starts at
  final DateTime startTime;

  /// The date of the concert
  final DateTime date;

  /// [Venue] of this event
  final Venue venue;

  /// The [Performance]s of this event
  final List<Performance> performances;

  /// ID of this event
  final int id;

  /// Url of webpage for ticket purchase
  final String url;

  /// Constructor
  Event({
    this.name,
    this.type,
    this.startTime,
    this.date,
    this.venue,
    this.performances,
    this.id,
    this.url,
  });

  /// Creates an Event from JSON data
  factory Event.fromJson(Map<String, dynamic> json) {
    return new Event(
      name: json['displayName'],
      type: json['type'],
      startTime: json['start'] is Map<String, String> &&
              json['start']['datetime'] != null
          ? DateTime.parse(json['start']['datetime'])
          : null,
      date:
          json['start'] is Map<String, String> && json['start']['date'] != null
              ? DateTime.parse(json['start']['date'])
              : null,
      venue: json['venue'] is Map<String, dynamic>
          ? new Venue.fromJson(json['venue'])
          : null,
      performances: json['performance'] is List<dynamic>
          ? json['performance']
              .map(
                  (Object performance) => new Performance.fromJson(performance))
              .toList()
          : <Performance>[],
      id: json['id'],
      url: json['uri'],
    );
  }
}

/// A single performance for an [Event]
class Performance {
  /// The billing of this performance
  ///
  /// ex. Headliner, Support...
  final String billing;

  /// The billing rank of this peformance within the event.
  /// (Order of appreance)
  final int billingIndex;

  /// The name of this performance
  ///
  /// This typically will be the name of the artist
  final String name;

  /// The artist of this performance
  final Artist artist;

  /// ID of this performance
  final int id;

  /// Constructor
  Performance({
    this.billing,
    this.billingIndex,
    this.name,
    this.artist,
    this.id,
  });

  /// Creates an Performance from JSON data
  factory Performance.fromJson(Map<String, dynamic> json) {
    return new Performance(
      billing: json['billing'],
      billingIndex: json['billingIndex'],
      name: json['displayName'],
      artist: json['artist'] is Map<String, dynamic>
          ? new Artist.fromJson(json['artist'])
          : null,
      id: json['id'],
    );
  }
}

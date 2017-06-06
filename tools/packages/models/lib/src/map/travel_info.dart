// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Travel Modes used to calculate travel duration
enum TravelMode {
  /// Driving a car
  driving,

  /// Walking
  walking,

  /// Biking
  bicycling,

  /// Using public transit
  transit,
}

/// This represents the travel time and distance between two locations
///
/// Based off the Google Maps Distance Matrix API:
/// https://developers.google.com/maps/documentation/distance-matrix/start
class TravelInfo {
  /// Text representation of distance
  ///
  /// ex. 23 mi
  final String distanceText;

  /// Distance in meters
  final int distanceInMeters;

  /// Text representation of duration
  ///
  /// ex. 2 hr 2 min
  final String durationText;

  /// Travel duration between the two locations
  final Duration duration;

  /// Constructor
  TravelInfo({
    this.distanceText,
    this.distanceInMeters,
    this.durationText,
    this.duration,
  });

  /// Creates an Event from JSON data
  factory TravelInfo.fromJson(Map<String, dynamic> json) {
    return new TravelInfo(
      distanceText: json['distance']['text'],
      distanceInMeters: json['distance']['value'],
      durationText: json['duration']['text'],
      duration: new Duration(seconds: json['duration']['value']),
    );
  }
}

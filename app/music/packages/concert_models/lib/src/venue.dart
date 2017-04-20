// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Model representing a Songkick venue
///
/// see: http://www.songkick.com/developer/venue-details
class Venue {
  /// Name of venue
  final String name;

  /// Description of venue
  final String description;

  /// Website of venue
  final String website;

  /// [MetroArea] that this venue belongs to
  final MetroArea metroArea;

  /// Street address of venue
  final String street;

  /// Zip Code of venue
  final String zip;

  /// ID of venue
  final int id;

  /// Constructor
  Venue({
    this.name,
    this.description,
    this.website,
    this.metroArea,
    this.street,
    this.zip,
    this.id,
  });

  /// Creates a Vanue from JSON data
  factory Venue.fromJson(Map<String, dynamic> json) {
    return new Venue(
      name: json['displayName'],
      description: json['description'],
      website: json['website'],
      metroArea: json['metroArea'] is Map<String, dynamic>
          ? new MetroArea.fromJson(json['metroArea'])
          : null,
      street: json['street'],
      zip: json['zip'],
      id: json['id'],
    );
  }

  /// Thumbnail image url for this venue
  String get imageUrl =>
      'http://images.sk-static.com/images/media/profile_images/venues/$id/col6';
}

/// Data model representing a Songkick Metro Area
///
/// Songkick uses a metro area to to group nearby events
class MetroArea {
  /// Name of metro area
  final String name;

  /// Country of metro area
  final String country;

  /// ID of metro area
  final int id;

  /// Constructor
  MetroArea({
    this.name,
    this.country,
    this.id,
  });

  /// Creates a MetroArea from JSON data
  factory MetroArea.fromJson(Map<String, dynamic> json) {
    return new MetroArea(
      name: json['displayName'],
      country: json['country'] is Map<String, String>
          ? json['country']['displayName']
          : null,
      id: json['id'],
    );
  }
}

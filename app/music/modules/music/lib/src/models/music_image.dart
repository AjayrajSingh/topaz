// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Model representing a Spotify Image Object
///
/// https://developer.spotify.com/web-api/object-model/#image-object
class MusicImage {
  /// Height of image
  final double height;

  /// Width of image
  final double width;

  /// Source URL of image
  final String url;

  /// Constructor
  MusicImage({
    this.height,
    this.width,
    this.url,
  });

  /// Creates a MusicImage object from json data
  factory MusicImage.fromJson(dynamic json) {
    return new MusicImage(
      height: json['height'] is int ? json['height'].roundToDouble() : null,
      width: json['width'] is int ? json['width'].roundToDouble() : null,
      url: json['url'],
    );
  }

  /// Creates of list of MusicImage objects from json data
  /// If json data is invalid, a empty list is returned
  static List<MusicImage> listFromJson(dynamic json) {
    List<MusicImage> images = <MusicImage>[];
    if (json is List<dynamic>) {
      List<dynamic> jsonList = json;
      jsonList.forEach((dynamic imageJson) {
        images.add(new MusicImage.fromJson(imageJson));
      });
    }
    return images;
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

final Color _kBackgroundColor = Colors.grey[300];
final Color _kIconColor = Colors.grey[600];

/// Renders the artwork for a track or playlist at a given size and provices
/// a fallback for situations when a track or playlist does not have artwork.
class TrackArt extends StatelessWidget {
  /// Size of the [TrackArt].
  ///
  /// Defaults to 48.0
  final double size;

  /// Url of artwork
  final String artworkUrl;

  /// Constructor
  TrackArt({
    Key key,
    this.artworkUrl,
    this.size: 48.0,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
      new Container(
        height: size,
        width: size,
        color: _kBackgroundColor,
        child: new Center(
          child: new Icon(
            Icons.music_note,
            color: _kIconColor,
            size: size / 2.0,
          ),
        ),
      ),
    ];

    if (artworkUrl != null) {
      children.add(new Image.network(
        artworkUrl,
        height: size,
        width: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ));
    }

    return new Stack(children: children);
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

final Color _kBackgroundColor = Colors.grey[300];
final Color _kIconColor = Colors.grey[600];

/// Fallback for situations when a track or playlist does not have artwork
class FallbackTrackArt extends StatelessWidget {
  /// Size of the [FallbackTrackArt].
  ///
  /// Defaults to 48.0
  final double size;

  FallbackTrackArt({
    Key key,
    this.size: 48.0,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Container(
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
    );
  }
}

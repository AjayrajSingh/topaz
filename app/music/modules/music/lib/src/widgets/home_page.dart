// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../models/album.dart';
import '../models/fixtures.dart';
import 'album_surface.dart';
import 'player.dart';

/// MyHomePage widget.
class MyHomePage extends StatelessWidget {
  /// MyHomePage constructor.
  MyHomePage({Key key, this.title}) : super(key: key);

  /// MyHomePage title.
  final String title;

  @override
  Widget build(BuildContext context) {
    Color highlightColor = Colors.pink[400];
    MusicModelFixtures fixture = new MusicModelFixtures();
    Album album = fixture.album();
    return new Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: new AppBar(
        title: new Text(title),
      ),
      body: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Expanded(
            child: new AlbumSurface(
              album: album,
              highlightColor: highlightColor,
              isFollowing: true,
              currentTrack: album.tracks[2],
            ),
          ),
          new Material(
            elevation: 4,
            child: new Player(
              currentTrack: fixture.track(),
              playbackPosition: new Duration(seconds: 60),
              highlightColor: highlightColor,
            ),
          ),
        ],
      ),
    );
  }
}

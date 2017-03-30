// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../models.dart';
import 'album_surface.dart';
import 'artist_surface.dart';
import 'player.dart';

enum _View {
  artist,
  album,
}

/// MyHomePage widget.
class MyHomePage extends StatefulWidget {
  /// MyHomePage constructor.
  MyHomePage({Key key, this.title}) : super(key: key);

  /// MyHomePage title.
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _View _currentView = _View.artist;

  void _toggleCurrentView() {
    if (_currentView == _View.artist) {
      setState(() => _currentView = _View.album);
    } else if (_currentView == _View.album) {
      setState(() => _currentView = _View.artist);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color highlightColor = Colors.pink[400];
    MusicModelFixtures fixture = new MusicModelFixtures();
    Album album = fixture.album();
    Artist artist = fixture.artist();
    Widget view;

    if (_currentView == _View.artist) {
      view = new SingleChildScrollView(
        controller: new ScrollController(),
        child: new ArtistSurface(
          artist: artist,
          highlightColor: highlightColor,
          isFollowing: true,
          relatedArtists: <Artist>[
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
            artist,
          ],
          albums: <Album>[
            album,
            album,
          ],
        ),
      );
    } else {
      view = new AlbumSurface(
        album: album,
        highlightColor: highlightColor,
        isFollowing: true,
        currentTrack: album.tracks[2],
      );
    }

    return new Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: new AppBar(
        title: new Text(config.title),
      ),
      body: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Expanded(
            child: view,
          ),
          new Material(
            elevation: 4,
            child: new Player(
              currentTrack: fixture.track(),
              playbackPosition: new Duration(seconds: 60),
              highlightColor: highlightColor,
              // For testing purposes only, tapping Play will toggle between
              // the two surfaces
              onTogglePlay: _toggleCurrentView,
            ),
          ),
        ],
      ),
    );
  }
}

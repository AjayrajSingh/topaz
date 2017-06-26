// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:last_fm_models/last_fm_models.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

/// UI Widget for an artist biography
class ArtistBio extends StatelessWidget {
  /// Artist to render biography for
  final Artist artist;

  /// Constructor
  ArtistBio({
    Key key,
    @required this.artist,
  })
      : super(key: key) {
    assert(artist != null);
  }

  @override
  Widget build(BuildContext context) {
    return new Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        new Container(
          padding: const EdgeInsets.all(32.0),
          decoration: new BoxDecoration(
            color: Colors.black,
            image: new DecorationImage(
              image: new AssetImage(
                'packages/last_fm_widgets/res/background.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              new Alphatar.withUrl(
                size: 56.0,
                avatarUrl: artist.imageUrl,
              ),
              new Container(
                padding: const EdgeInsets.only(left: 16.0),
                child: new Text(
                  artist.name,
                  style: new TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 20.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        new Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32.0),
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Container(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: new Text(
                  'Biography',
                  style: new TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 20.0,
                  ),
                ),
              ),
              new Text(
                artist.bio,
                softWrap: true,
                style: new TextStyle(
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

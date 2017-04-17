// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';
import 'package:music_models/music_models.dart';

import 'typedefs.dart';

const double _kGridPadding = 32.0;
const double _kTargetGridItemWidth = 160.0;

/// Renders a grid of [Artist]s
class ArtistGrid extends StatelessWidget {
  /// List of Artists to render
  final List<Artist> artists;

  /// Callback for when an artist is tapped
  final ArtistActionCallback onTapArtist;

  /// Constructor
  ArtistGrid({
    Key key,
    @required this.artists,
    this.onTapArtist,
  })
      : super(key: key) {
    assert(artists != null);
  }

  Widget _buildArtistGridItem({
    Artist artist,
    double width,
  }) {
    return new CupertinoButton(
      onPressed: () => onTapArtist?.call(artist),
      pressedOpacity: 0.7,
      padding: EdgeInsets.zero,
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          new Alphatar.withUrl(
            avatarUrl: artist.defaultArtworkUrl,
            backgroundColor: Colors.grey[400],
            size: width,
          ),
          new Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            alignment: FractionalOffset.center,
            child: new Text(
              artist.name,
              style: const TextStyle(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Compute the optimal number of columns based on desired item size
        // and the given constraints
        int columnCount =
            (constraints.maxWidth / _kTargetGridItemWidth).round();
        if (columnCount == 0) {
          columnCount = 1;
        }
        double columnSize = max(
          (constraints.maxWidth - (columnCount + 1) * _kGridPadding) /
              columnCount,
          0.0,
        );

        // Track each column as a list of widgets
        List<List<Widget>> columnChildren = <List<Widget>>[];
        for (int i = 0; i < columnCount; i++) {
          columnChildren.add(<Widget>[]);
        }

        // Place each artist widget in the appropiate column
        for (int i = 0; i < artists.length; i++) {
          int columnIndex = i % columnCount;
          columnChildren[columnIndex].add(new Container(
            padding: const EdgeInsets.all(_kGridPadding / 2.0),
            child: _buildArtistGridItem(
              artist: artists[i],
              width: columnSize,
            ),
          ));
        }

        // Give columns equal flex value to ensure that the widths are equally
        // distributed.
        List<Widget> columns = <Widget>[];
        for (int i = 0; i < columnCount; i++) {
          columns.add(new Expanded(
            flex: 1,
            child: new Column(
              children: columnChildren[i],
            ),
          ));
        }

        return new Container(
          padding: const EdgeInsets.all(_kGridPadding / 2.0),
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns,
          ),
        );
      },
    );
  }
}

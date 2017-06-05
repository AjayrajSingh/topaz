// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../modular/module_model.dart';

/// The play bar to video player.
class PlayBar extends StatelessWidget {
  /// Model that stores video playback state
  final VideoModuleModel model;

  /// The play bar for video player
  PlayBar({
    this.model,
    Key key,
  })
      : super(key: key);

  Widget _createIconButton(Icon icon, VoidCallback callback) {
    return new Container(
      child: new IconButton(
        icon: icon,
        iconSize: 28.0,
        color: Colors.grey[50],
        disabledColor: Colors.grey[800],
        onPressed: callback,
      ),
    );
  }

  void _togglePlayPause() {
    model.togglePlayPause();
  }

  // TODO SO-447 use API to calculate progress
  double _getProgress() {
    return 50.0;
  }

  @override
  Widget build(BuildContext context) {
    Widget progressBar = new Stack(
      children: <Widget>[
        new Container(height: 2.0, color: Colors.grey[800]),
        new Container(
            height: 2.0, color: Colors.grey[50], width: _getProgress()),
      ],
    );
    Widget playBarButtons = new Center(
      child: new Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _createIconButton(new Icon(Icons.fast_rewind), null),
          model.isPlaying
              ? _createIconButton(new Icon(Icons.play_arrow), _togglePlayPause)
              : _createIconButton(new Icon(Icons.pause), _togglePlayPause),
          _createIconButton(new Icon(Icons.fast_forward), null),
        ],
      ),
    );
    Widget timestamp = new Positioned(
      right: 0.0,
      child: new Center(
        child: new Container(
          height: 45.0,
          alignment: FractionalOffset.center,
          padding: new EdgeInsets.only(right: 24.0),
          child: new Text(
            '1:50',
            style: new TextStyle(
              color: Colors.grey[50],
              fontSize: 14.0,
            ),
          ),
        ),
      ),
    );
    return new Container(
      color: Colors.black,
      child: new Stack(
        children: <Widget>[
          timestamp,
          progressBar,
          playBarButtons,
        ],
      ),
    );
  }
}

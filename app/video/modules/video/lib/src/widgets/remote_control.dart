// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../widgets.dart';

/// Remote control mode for the video player
class RemoteControl extends StatelessWidget {
  /// Play video locally
  final VoidCallback playLocal;

  /// Name of remote device currently playing the video
  final String remoteDeviceName;

  /// Video asset
  final Asset asset;

  /// Remote control layout is on a small (phone-sized) screen
  final bool smallScreen;

  /// Constructor for remote control mode for the video player
  RemoteControl({
    Key key,
    @required this.playLocal,
    @required this.remoteDeviceName,
    @required this.asset,
    @required this.smallScreen,
  })
      : super(key: key) {
    assert(playLocal != null);
    assert(remoteDeviceName != null);
    assert(asset != null);
    assert(smallScreen != null);
  }

  @override
  Widget build(BuildContext context) {
    Widget thumbnail = new Align(
      alignment: FractionalOffset.bottomCenter,
      child: new Container(
        margin: new EdgeInsets.all(20.0),
        width: 360.0,
        child: new Image.asset(asset.thumbnail),
      ),
    );

    Widget videoText = new Center(
      child: new Column(
        children: <Widget>[
          new Padding(
            padding: new EdgeInsets.symmetric(
                vertical: this.smallScreen ? 0.0 : 8.0),
            child: new Text(
              asset.title,
              style: new TextStyle(
                color: Colors.grey[50],
                fontSize: 24.0,
                letterSpacing: 0.02,
              ),
            ),
          ),
          new Container(
            width: 400.0,
            padding: new EdgeInsets.only(bottom: 4.0),
            child: new Text(
              this.smallScreen ? '' : asset.description,
              textAlign: TextAlign.center,
              style: new TextStyle(
                color: Colors.grey[500],
                fontSize: 16.0,
                letterSpacing: 0.02,
              ),
            ),
          ),
        ],
      ),
    );

    Widget uncastToast = new Positioned(
      top: 16.0,
      right: 16.0,
      child: new GestureDetector(
        onTap: playLocal,
        child: new Container(
          decoration: new BoxDecoration(
            borderRadius: new BorderRadius.circular(16.0),
            color: Colors.grey[800],
          ),
          padding: new EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: new Row(
            children: <Widget>[
              new Icon(
                Icons.cast,
                size: 20.0,
                color: Colors.grey[50],
              ),
              new Padding(
                padding: new EdgeInsets.symmetric(horizontal: 16.0),
                child: new Text(
                  remoteDeviceName ?? 'Remote Device',
                  style: new TextStyle(
                    fontSize: 14.0,
                    color: Colors.grey[50],
                    letterSpacing: 0.02,
                  ),
                ),
              ),
              new Icon(
                Icons.close,
                size: 20.0,
                color: Colors.grey[50],
              ),
            ],
          ),
        ),
      ),
    );

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        new Expanded(
          flex: 3,
          child: new Stack(
            children: <Widget>[
              thumbnail,
              uncastToast,
            ],
          ),
        ),
        new Expanded(
          flex: 1,
          child: videoText,
        ),
        new Expanded(
          flex: this.smallScreen ? 5 : 2,
          child: new Scrubber(),
        ),
      ],
    );
  }
}

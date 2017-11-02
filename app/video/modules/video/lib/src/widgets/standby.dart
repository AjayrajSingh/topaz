// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

import '../widgets.dart';

/// Standby (uncast) mode for the video player
class Standby extends StatelessWidget {
  /// Name of casting device currently playing the video
  final String castingDeviceName;

  /// Video asset
  final Asset asset;

  /// Constructor for standby mode
  const Standby({
    Key key,
    @required this.castingDeviceName,
    @required this.asset,
  })
      : assert(asset != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget thumbnail = new Align(
      alignment: FractionalOffset.bottomCenter,
      child: new Container(
        margin: const EdgeInsets.all(24.0),
        width: 400.0,
        child: new Image.asset(asset.thumbnail),
      ),
    );

    Widget background = new Opacity(
      opacity: 0.3,
      child: new Image.asset(
        asset.background,
        fit: BoxFit.cover,
      ),
    );

    Widget castingDeviceInfo = new Positioned(
      top: 32.0,
      right: 32.0,
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          new Text(
            'You are watching on',
            style: new TextStyle(
              fontSize: 14.0,
              color: Colors.grey[50],
              letterSpacing: 0.02,
            ),
          ),
          new Row(
            children: <Widget>[
              new Icon(
                Icons.tablet,
                size: 28.0,
                color: Colors.grey[50],
              ),
              new Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: new Text(
                  castingDeviceName ?? 'Acer',
                  style: new TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey[50],
                    letterSpacing: 0.02,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    Widget videoText = new Center(
      child: new Column(
        children: <Widget>[
          new Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: new Text(
              asset.title,
              style: new TextStyle(
                color: Colors.grey[50],
                fontSize: 28.0,
                letterSpacing: 0.02,
              ),
            ),
          ),
          new Container(
            width: 550.0,
            padding: const EdgeInsets.only(bottom: 4.0),
            child: new Text(
              asset.description,
              textAlign: TextAlign.center,
              style: new TextStyle(
                color: Colors.grey[500],
                fontSize: 18.0,
                letterSpacing: 0.02,
              ),
            ),
          ),
        ],
      ),
    );

    return new Stack(
      children: <Widget>[
        new Positioned.fill(
          child: background,
        ),
        castingDeviceInfo,
        new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              thumbnail,
              videoText,
            ],
          ),
        ),
      ],
    );
  }
}

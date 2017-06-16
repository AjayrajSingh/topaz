// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../modular/module_model.dart';
import '../widgets.dart';

/// Remote control mode for the video player
class RemoteControl extends StatelessWidget {
  /// Play video locally
  final VoidCallback playLocal;

  /// Play video locally
  final String remoteDeviceName;

  /// Constructor for remote control mode for the video player
  RemoteControl({
    Key key,
    @required this.playLocal,
    @required this.remoteDeviceName,
  })
      : super(key: key);

  // TODO(maryxia) SO-520 add real thumbnail image
  final Widget _thumbnail = new Align(
    alignment: FractionalOffset.bottomCenter,
    child: new Container(
      color: Colors.pink,
      height: 180.0,
      width: 320.0,
    ),
  );

  // TODO(maryxia) SO-520 add real video text
  final Widget _videoText = new Center(
    child: new Column(
      children: <Widget>[
        new Padding(
          padding: new EdgeInsets.symmetric(vertical: 8.0),
          child: new Text(
            'Video name',
            style: new TextStyle(
              color: Colors.grey[50],
              fontSize: 20.0,
              letterSpacing: 0.02,
            ),
          ),
        ),
        new Padding(
          padding: new EdgeInsets.only(bottom: 4.0),
          child: new Text(
            'Video description',
            style: new TextStyle(
              color: Colors.grey[500],
              fontSize: 14.0,
              letterSpacing: 0.02,
            ),
          ),
        ),
        new Scrubber(height: 2.0),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
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
          padding: new EdgeInsets.all(8.0),
          child: new Row(
            children: <Widget>[
              new Icon(
                Icons.cast,
                size: 20.0,
                color: Colors.grey[50],
              ),
              new Padding(
                padding: new EdgeInsets.symmetric(horizontal: 8.0),
                child: new Text(
                  remoteDeviceName,
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
    return new ScopedModelDescendant<VideoModuleModel>(builder: (
      BuildContext context,
      Widget child,
      VideoModuleModel model,
    ) {
      return new Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          new Expanded(
            flex: 5,
            child: new Stack(
              children: <Widget>[
                uncastToast,
                _thumbnail,
              ],
            ),
          ),
          new Expanded(
            flex: 2,
            child: _videoText,
          ),
          new Expanded(
            flex: 2,
            child: new PlayControls(
              primaryIconSize: 48.0,
              secondaryIconSize: 48.0,
              padding: 36.0,
            ),
          ),
        ],
      );
    });
  }
}

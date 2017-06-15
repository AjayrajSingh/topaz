// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';

/// The device chooser in the video player, for casting to another device
class DeviceChooser extends StatelessWidget {
  /// Constructor for the device chooser in the video player
  DeviceChooser({
    Key key,
  })
      : super(key: key);

  Widget _createDropTarget(
      IconData icon, VoidCallback callback, VideoModuleModel model) {
    return new DragTarget<String>(
      onWillAccept: (String deviceName) => true,
      onAccept: (String deviceName) => callback(),
      builder: (BuildContext context, List<String> candidateData,
              List<dynamic> rejectedData) =>
          new Container(
            child: new Column(
              children: <Widget>[
                new Padding(
                  padding: new EdgeInsets.only(top: 40.0, bottom: 10.0),
                  child: new Icon(
                    icon,
                    size: 100.0,
                    color: Colors.grey[400],
                  ),
                ),
                // TODO(maryxia) SO-449 Get real device name
                new Text(
                  'Living Room TV'.toUpperCase(),
                  style: new TextStyle(
                    color: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return new Offstage(
          offstage: model.hideDeviceChooser,
          child: new Container(
            color: Colors.black,
            child: new Center(
              child: new Row(
                mainAxisSize: MainAxisSize.min,
                // TODO(maryxia) SO-449 Get real list of devices
                children: <Widget>[
                  _createDropTarget(Icons.cast, model.playRemote, model),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

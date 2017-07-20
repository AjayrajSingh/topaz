// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';
import 'device_target_icon.dart';

/// Callback to start remote play on a particular device
typedef void DeviceCallback(String deviceName);

/// The device chooser in the video player, for casting to another device
class DeviceChooser extends StatelessWidget {
  /// Constructor for the device chooser in the video player
  DeviceChooser({
    Key key,
  })
      : super(key: key);

  Widget _createDropTarget(
    String dropTargetName,
    String displayName,
    IconData icon,
    DeviceCallback callback,
    VideoModuleModel model,
  ) {
    return new Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: new DragTarget<String>(
        onWillAccept: (String deviceName) => true,
        onAccept: (String deviceName) => callback(dropTargetName),
        builder: (BuildContext context, List<String> candidateData,
            List<dynamic> rejectedData) {
          return new DeviceTargetIcon(
            focused: candidateData.isNotEmpty,
            icon: icon,
            deviceName: displayName,
          );
        },
      ),
    );
  }

  // Create drop target for all remote devices
  List<Widget> _createDropTargets(
      IconData icon, DeviceCallback callback, VideoModuleModel model) {
    model.refreshRemoteDevices();
    List<Widget> dropTargets = <Widget>[];
    if (model.activeDevices.isEmpty) {
      dropTargets.add(new Container(
        padding: new EdgeInsets.only(top: 32.0),
        child: new Text(
          'No devices detected',
          style: new TextStyle(
            color: Colors.grey[50],
            fontSize: 24.0,
            letterSpacing: 0.02,
          ),
        ),
      ));
    } else {
      for (String deviceName in model.activeDevices) {
        String displayName = model.getDisplayName(deviceName);

        dropTargets.add(
            _createDropTarget(deviceName, displayName, icon, callback, model));
      }
    }

    return dropTargets;
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
                children:
                    _createDropTargets(Icons.cast, model.playRemote, model),
              ),
            ),
          ),
        );
      },
    );
  }
}

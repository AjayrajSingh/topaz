// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

const double _kDefaultIconSize = 64.0;
final Color _kDefaultColor = Colors.grey[500];
final Color _kFocusedColor = Colors.white;

/// Device Drop Target Icon that animates based on if it is focused
class DeviceTargetIcon extends StatefulWidget {
  /// Constructor
  const DeviceTargetIcon({
    Key key,
    @required this.icon,
    @required this.deviceName,
    this.focused: false,
  })
      : assert(icon != null),
        assert(deviceName != null),
        super(key: key);

  /// Icon that represents the device
  final IconData icon;

  /// Name of device
  final String deviceName;

  /// If true the DeviceTargetIcon will be highlighted
  final bool focused;

  @override
  _DeviceTargetIconState createState() => new _DeviceTargetIconState();
}

class _DeviceTargetIconState extends State<DeviceTargetIcon>
    with TickerProviderStateMixin {
  AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = new AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    if (widget.focused) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(DeviceTargetIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused != widget.focused) {
      if (widget.focused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new AnimatedBuilder(
        animation: _animationController,
        builder: (BuildContext context, Widget child) {
          Color colorLerp = Color.lerp(
            _kDefaultColor,
            _kFocusedColor,
            _animationController.value,
          );
          return new ScaleTransition(
            scale: new Tween<double>(
              begin: 1.0,
              end: 1.5,
            )
                .animate(_animationController),
            child: new Container(
              child: new Column(
                children: <Widget>[
                  new Padding(
                    padding: const EdgeInsets.only(top: 40.0, bottom: 10.0),
                    child: new Icon(
                      widget.icon,
                      size: _kDefaultIconSize,
                      color: colorLerp,
                    ),
                  ),
                  new Text(
                    widget.deviceName.toUpperCase(),
                    style: new TextStyle(
                      color: colorLerp,
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

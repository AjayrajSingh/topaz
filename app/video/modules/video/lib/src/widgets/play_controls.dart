// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../modular/module_model.dart';

/// The play controls in the video player
class PlayControls extends StatelessWidget {
  final double _kZoomTimeInMicroseconds = 3000000.0;

  /// Size of the play/pause icons
  final double primaryIconSize;

  /// Size of the fast forward and rewind icons
  final double secondaryIconSize;

  /// Padding around play control icons
  final double padding;

  /// Constructor for the play controls in the video player
  PlayControls({
    Key key,
    @required this.primaryIconSize,
    @required this.secondaryIconSize,
    @required this.padding,
  })
      : super(key: key);

  Widget _createIconButton(Icon icon, double iconSize, VoidCallback callback) {
    return new Container(
      padding: new EdgeInsets.all(padding),
      child: new IconButton(
        icon: icon,
        iconSize: iconSize,
        color: Colors.grey[50],
        disabledColor: Colors.grey[500],
        onPressed: callback,
      ),
    );
  }

  double _getZoomTime(VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return 0.0;
    }
    return _kZoomTimeInMicroseconds / durationInMicroseconds;
  }

  void _forward(VideoModuleModel model) {
    model.pause();
    model.normalizedSeek(
        min(model.normalizedProgress + _getZoomTime(model), 1.0));
    model.play();
  }

  void _rewind(VideoModuleModel model) {
    model.pause();
    model.normalizedSeek(
        max(model.normalizedProgress - _getZoomTime(model), 0.0));
    model.play();
  }

  void _togglePlayPause(VideoModuleModel model) {
    if (model.playing) {
      model.pause();
    } else {
      model.play();
    }
  }

  Widget _buildPlayControls(VideoModuleModel model) {
    return new Offstage(
      offstage: false,
      child: new Center(
        child: new Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _createIconButton(
              new Icon(Icons.fast_rewind),
              secondaryIconSize,
              model.progress.inMicroseconds == 0 ? null : () => _rewind(model),
            ),
            model.playing
                ? _createIconButton(new Icon(Icons.pause), primaryIconSize,
                    () => _togglePlayPause(model))
                : _createIconButton(new Icon(Icons.play_arrow), primaryIconSize,
                    () => _togglePlayPause(model)),
            _createIconButton(
                new Icon(Icons.fast_forward),
                secondaryIconSize,
                model.progress.inMicroseconds == model.duration.inMicroseconds
                    ? null
                    : () => _forward(model)),
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
        return _buildPlayControls(model);
      },
    );
  }
}

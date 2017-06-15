// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import '../modular/module_model.dart';

/// The play controls in the video player
class PlayControls extends StatelessWidget {
  final double _kZoomTimeInMicroseconds = 3000000.0;

  /// Constructor for the play controls in the video player
  PlayControls({
    Key key,
  })
      : super(key: key);

  Widget _createIconButton(Icon icon, VoidCallback callback) {
    return new Container(
      child: new IconButton(
        icon: icon,
        iconSize: 150.0,
        color: Colors.grey[50],
        disabledColor: Colors.grey[500],
        onPressed: callback,
      ),
    );
  }

  /// Returns progress as a value from 0.0 to 1.0 inclusive.
  double _getUnitProgress(VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return 0.0;
    }
    return model.progress.inMicroseconds / durationInMicroseconds;
  }

  /// Seeks to a position given as a value from 0.0 to 1.0 inclusive.
  void _unitSeek(double unitPosition, VideoModuleModel model) {
    int durationInMicroseconds = model.duration.inMicroseconds;
    if (durationInMicroseconds == 0) {
      return;
    }
    model.seek(new Duration(
        microseconds: (unitPosition * durationInMicroseconds).round()));
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
    _unitSeek(min(_getUnitProgress(model) + _getZoomTime(model), 1.0), model);
    model.play();
  }

  void _rewind(VideoModuleModel model) {
    model.pause();
    _unitSeek(max(_getUnitProgress(model) - _getZoomTime(model), 0.0), model);
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
      // TODO(maryxia) SO-480 offstage depends on device chooser AND timeout
      offstage: false,
      child: new Center(
        child: new Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _createIconButton(
                new Icon(Icons.fast_rewind),
                model.progress.inMicroseconds == 0
                    ? null
                    : () => _rewind(model)),
            model.playing
                ? _createIconButton(
                    new Icon(Icons.pause), () => _togglePlayPause(model))
                : _createIconButton(
                    new Icon(Icons.play_arrow), () => _togglePlayPause(model)),
            _createIconButton(
                new Icon(Icons.fast_forward),
                model.progress.inMicroseconds == model.duration.inMicroseconds
                    ? null
                    : () => _forward(model)),
            // TODO(maryxia) SO-445 add less-hideous "uncast" toast notification
            model.remote
                ? _createIconButton(
                    new Icon(Icons.cancel),
                    model.playLocal,
                  )
                : new Container(),
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

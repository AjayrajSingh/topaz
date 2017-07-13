// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ui' show lerpDouble;

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import '../modular/module_model.dart';

/// The video screen for the video player
class Screen extends StatefulWidget {
  /// Constructor for the video screen for the video player
  Screen({Key key}) : super(key: key);

  @override
  _ScreenState createState() => new _ScreenState();
}

class _ScreenState extends State<Screen> {
  static const double _kThumbWidth = 120.0;
  static const double _kThumbHeight = 83.0;

  /// Local variable to save the state immediately before animating the screen
  /// into thumbnail.
  bool wasPlayingBefore = false;

  Rect _animateIntoThumbnail(VideoModuleModel model) {
    wasPlayingBefore = model.playing;
    if (wasPlayingBefore) {
      model.pause();
    }
    model.hideDeviceChooser = false;
    model.thumbnailAnimationController.forward();
    return new Rect.fromLTWH(0.0, 0.0, 0.0, 0.0);
  }

  void _animateIntoScreen(VideoModuleModel model) {
    model.hideDeviceChooser = true;
    model.thumbnailAnimationController.reverse();
    if (wasPlayingBefore) {
      model.play();
    }
  }

  void _toggleControlOverlay(VideoModuleModel model) {
    if (model.showControlOverlay) {
      model.showControlOverlay = false;
    } else {
      model.brieflyShowControlOverlay();
    }
  }

  Widget _buildScreen(VideoModuleModel model, BuildContext context) {
    LayoutBuilder layoutBuilder = new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double currentWidth = constraints.maxWidth;
      double currentHeight = constraints.maxHeight;
      return new Center(
        child: new LongPressDraggable<String>(
          data: '',
          dragAnchor: DragAnchor.pointer,
          childWhenDragging: new Container(),
          feedback: new AnimatedBuilder(
            animation: model.thumbnailAnimationController,
            child: new Container(
              margin: new EdgeInsets.only(right: 3.0, bottom: 3.0),
              decoration: new BoxDecoration(
                color: Colors.black,
                boxShadow: <BoxShadow>[
                  new BoxShadow(
                    color: Colors.grey[500],
                    offset: new Offset(1.0, 1.0),
                    blurRadius: BoxShadow.convertRadiusToSigma(1.0),
                  ),
                ],
                border: new Border.all(
                  width: 1.0,
                  color: Colors.grey[500],
                ),
              ),
              child: model.videoViewConnection != null
                  ? new ChildView(connection: model.videoViewConnection)
                  : null,
            ),
            builder: (BuildContext context, Widget child) {
              double lerpWidth = lerpDouble(
                  currentWidth, _kThumbWidth, model.thumbnailAnimation.value);
              double lerpHeight = lerpDouble(
                  currentHeight, _kThumbHeight, model.thumbnailAnimation.value);
              double x = -lerpWidth / 2.0;
              double y = -lerpHeight / 2.0;

              return new Transform(
                transform: new Matrix4.translationValues(x, y, 0.0),
                child: new Container(
                  width: lerpWidth,
                  height: lerpHeight,
                  child: new Container(
                    child: new ClipRRect(
                      borderRadius: new BorderRadius.circular(
                        _kThumbWidth * model.thumbnailAnimation.value,
                      ),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
          onDragStarted: () => _animateIntoThumbnail(model),
          onDraggableCanceled: (Velocity v, Offset o) =>
              _animateIntoScreen(model),
          child: model.videoViewConnection != null
              ? new GestureDetector(
                  onTap: () => _toggleControlOverlay(model),
                  child: new AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: new ChildView(connection: model.videoViewConnection),
                  ),
                )
              : new FuchsiaSpinner(),
        ),
      );
    });
    return layoutBuilder;
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<VideoModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        VideoModuleModel model,
      ) {
        return _buildScreen(model, context);
      },
    );
  }
}

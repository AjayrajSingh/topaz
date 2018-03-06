// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import '../modular/player_model.dart';
import 'loading.dart';

/// The video screen for the video player
class Screen extends StatefulWidget {
  /// Constructor for the video screen for the video player
  const Screen({Key key}) : super(key: key);

  @override
  _ScreenState createState() => new _ScreenState();
}

class _ScreenState extends State<Screen> with TickerProviderStateMixin {
  static const double _kThumbRadius = 120.0;
  AnimationController _thumbnailAnimationController;
  Animation<double> _thumbnailAnimation;

  // Save the state immediately before animating the frame into thumbnail
  bool _wasPlayingBefore = false;

  @override
  void initState() {
    super.initState();
    _thumbnailAnimationController = new AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _thumbnailAnimation = new CurvedAnimation(
      parent: _thumbnailAnimationController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _thumbnailAnimationController.dispose();
  }

  void _animateIntoThumbnail(PlayerModel playerModel) {
    _wasPlayingBefore = playerModel.playing;
    if (_wasPlayingBefore) {
      playerModel.pause();
    }
    _thumbnailAnimationController.forward();
  }

  void _animateIntoScreen(PlayerModel playerModel) {
    _thumbnailAnimationController.reverse();
    if (_wasPlayingBefore) {
      playerModel.play();
    }
  }

  void _toggleControlOverlay(PlayerModel playerModel) {
    if (playerModel.showControlOverlay) {
      playerModel.showControlOverlay = false;
    } else {
      playerModel.brieflyShowControlOverlay();
    }
  }

  Widget _buildScreen(
    PlayerModel playerModel,
    BuildContext context,
  ) {
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
            animation: _thumbnailAnimationController,
            child: new Container(
              height: _kThumbRadius,
              width: _kThumbRadius,
              color: Colors.black,
              child: playerModel.videoViewConnection != null
                  ? new FittedBox(
                      fit: BoxFit.cover,
                      child: new Container(
                        width: _kThumbRadius,
                        child: new AspectRatio(
                          aspectRatio: 16.0 / 9.0,
                          child: new ChildView(
                              connection: playerModel.videoViewConnection),
                        ),
                      ),
                    )
                  : null,
            ),
            builder: (BuildContext context, Widget child) {
              double lerpWidth = lerpDouble(
                currentWidth,
                _kThumbRadius,
                _thumbnailAnimation.value,
              );
              double lerpHeight = lerpDouble(
                currentHeight,
                _kThumbRadius,
                _thumbnailAnimation.value,
              );
              double x = -lerpWidth / 2.0;
              double y = -lerpHeight / 2.0;
              BorderRadius borderRadius = new BorderRadius.circular(
                _kThumbRadius * _thumbnailAnimation.value,
              );
              return new Transform(
                transform: new Matrix4.translationValues(x, y, 0.0),
                child: new PhysicalModel(
                  borderRadius: borderRadius,
                  color: Colors.grey[500],
                  child: new Container(
                    width: lerpWidth,
                    height: lerpHeight,
                    decoration: new BoxDecoration(
                      border: new Border.all(
                        width: 2.0,
                        color: Colors.grey[500],
                      ),
                    ),
                    child: new ClipRRect(
                      borderRadius: borderRadius,
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
          onDragStarted: () => _animateIntoThumbnail(playerModel),
          onDraggableCanceled: (Velocity v, Offset o) =>
              _animateIntoScreen(playerModel),
          child: playerModel.videoViewConnection != null
              ? new GestureDetector(
                  onTap: () => _toggleControlOverlay(playerModel),
                  child: new AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: new ChildView(
                        connection: playerModel.videoViewConnection),
                  ),
                )
              : const Loading(remoteDeviceName: 'Unknown'),
        ),
      );
    });
    return layoutBuilder;
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<PlayerModel>(builder: (
      BuildContext context,
      Widget child,
      PlayerModel playerModel,
    ) {
      return new ScopedModelDescendant<PlayerModel>(builder: (
        BuildContext context,
        Widget child,
        PlayerModel playerModel,
      ) {
        return _buildScreen(playerModel, context);
      });
    });
  }
}

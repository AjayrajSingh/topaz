// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:lib.app.dart/app.dart';
import 'package:lib.media.flutter/media_player_controller.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

final Uri _kVideoUri = Uri.parse(
  'https://storage.googleapis.com/'
      'fuchsia/assets/video/656a7250025525ae5a44b43d23c51e38b466d146',
);

const double _kElevationStep = 2.0;
const double _kAlbumMakerWidth = 672.0;
const double _kAlbumMakerImageWidth = 492.0;
const double _kAlbumMakerImageMargin = 32.0;
const double _kPhotoListWidth = 428.0;
const double _kPhotoListHeight = 548.0;
const double _kPhotoListPhotoMargin = 4.0;
const double _kPhotoListTitleHeight = 96.0;
const double _kPhotoListHorizontalMargin = 8.0;
const double _kAutoMagicHorizontalOverlap = 56.0;
const double _kAutoMagicBottomOffset = 48.0;
const double _kAutoMagicSize = 80.0;
const double _kAutoMagicIconSize = 40.0;
const double _kSearchBoxTopOffset = 40.0;
const double _kSearchBoxHeight = 56.0;
const double _kSearchBoxWidth = 328.0;
const double _kSunBottomOffset = -60.0;
const double _kPhotoListCheckInset = 16.0;
const double _kPhotoListCheckSize = 24.0;
const double _kPhotoListVideoIconSize = 40.0;
const double _kPhotoListQuadPictureHeight = 272.0;
const double _kPhotoListTitleLeftPadding = 24.0;
const double _kPhotoListTitleRightPadding = 48.0;
const double _kPhotoListTitleFontSize = 24.0;
const double _kPhotoListDescriptionFontSize = 14.0;
const double _kSearchBoxIconSize = 24.0;
const double _kSearchBoxTextSize = 14.0;
const double _kSearchBoxHorizontalMargin = 16.0;
const double _kSunRayWidth = 26.0;
const double _kSunRayHeight = 17.0;
const double _kSunCenterDiameter = 102.0;
const double _kSunCenterMargin = 18.0;
const double _kSunDiameter =
    _kSunCenterDiameter + 2.0 * _kSunRayWidth + 2.0 * _kSunCenterMargin;
const double _kSunRayOffset =
    _kSunCenterDiameter / 2.0 + _kSunRayWidth / 2.0 + _kSunCenterMargin;
const double _kSqrt2 = 0.707;
const double _kVideoPlayerWidth = 840.0;
const double _kVideoPlayerHeight = 580.0;
const double _kVideoPlayerProgressBarHeight = 3.0;
const double _kVideoPlayerTextSize = 14.0;
const double _kVideoPlayerIconSize = 48.0;
const double _kVideoPlayerTextHorizontalMargin = 24.0;
const double _kVideoPlayerTextTopMargin = 24.0;
const double _kVideoPlayerButtonHorizontalPadding = 32.0;
const double _kVideoPlayerButtonHeight = 92.0;
const double _kVideoPlayerButtonWidth =
    _kVideoPlayerIconSize + 2 * _kVideoPlayerButtonHorizontalPadding;

const double _kAlbumMakerElevation = 2 * _kElevationStep;
const double _kPhotoListElevation = 4 * _kElevationStep;
const double _kAutoMagicElevation = 16 * _kElevationStep;
const double _kVideoPlayerElevation = 18 * _kElevationStep;

// Relative to _kAlbumMakerElevation
const double _kSunRelativeElevation = 5 * _kElevationStep;

// Relative to _kPhotoListElevation
const double _kPhotoListTitleRelativeElevation = 4 * _kElevationStep;

// Relative to _kAlbumMakerElevation
const double _kSearchBoxRelativeElevation = 3 * _kElevationStep;

final BorderRadius _kAlbumMakerBorderRadius = new BorderRadius.circular(16.0);
final BorderRadius _kPhotoListBorderRadius = new BorderRadius.circular(16.0);
final BorderRadius _kSearchBoxBorderRadius = new BorderRadius.circular(8.0);
final BorderRadius _kVideoPlayerBorderRadius = new BorderRadius.only(
  bottomLeft: const Radius.circular(16.0),
  bottomRight: const Radius.circular(16.0),
);

const Color _kAutoMagicButtonBackgroundColor = const Color(0xFF4A78C0);
final Color _kAlbumMakerBackgroundColor = Colors.grey[50];
final Color _kPhotoListBackgroundColor = Colors.grey[50];
final Color _kPhotoListCheckBackgroundColor = Colors.grey[900];
final Color _kPhotoListCheckIconColor = Colors.grey[100];
final Color _kPhotoListTitleColor = Colors.grey[900];
final Color _kSearchBoxBackgroundColor = Colors.grey[50];
final Color _kSearchBoxTextColor = Colors.grey[600];
final Color _kSunColor = Colors.yellow;

final Duration _kVideoSkipAmount = const Duration(seconds: 10);
final Duration _kVideoProgressTimeout = const Duration(milliseconds: 250);

final ApplicationContext _applicationContext =
    new ApplicationContext.fromStartupInfo();

Future<Null> main() async {
  MediaPlayerController controller = new MediaPlayerController(
    _applicationContext.environmentServices,
  )..open(_kVideoUri);

  _VideoModel videoModel = new _VideoModel(controller: controller);

  runApp(
    new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => constraints
                      .biggest.width ==
                  0.0 ||
              constraints.biggest.height == 0.0
          ? const Offstage()
          : new Directionality(
              textDirection: TextDirection.ltr,
              child: new WindowMediaQuery(
                child: new GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => videoModel.hideVideo(),
                  child: new Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Album Maker.
                      new Positioned(
                        left: 0.0,
                        top: 0.0,
                        bottom: 0.0,
                        width: _kAlbumMakerWidth,
                        child: new _AlbumMaker(),
                      ),

                      // Photo list.
                      new Positioned(
                        right: 0.0,
                        bottom: 0.0,
                        width: _kPhotoListWidth,
                        height: _kPhotoListHeight,
                        child: new _PhotoList(
                          onVideoTapped: () => videoModel.toggleVideo(),
                        ),
                      ),

                      // Auto Magic Button.
                      new Positioned(
                        right: _kPhotoListWidth - _kAutoMagicHorizontalOverlap,
                        bottom: _kAutoMagicBottomOffset,
                        width: _kAutoMagicSize,
                        height: _kAutoMagicSize,
                        child: new _AutoMagicButton(),
                      ),

                      // Video Player.
                      new Center(
                        child: new SizedBox(
                          width: _kVideoPlayerWidth,
                          height: _kVideoPlayerHeight,
                          child: new ScopedModel<_VideoModel>(
                            model: videoModel,
                            child: new LayoutBuilder(
                              builder: (_, BoxConstraints constraints) =>
                                  (constraints.maxWidth == 0.0 ||
                                          constraints.maxHeight == 0.0)
                                      ? const Offstage()
                                      : new ScopedModelDescendant<_VideoModel>(
                                          builder:
                                              (_, __, _VideoModel videoModel) =>
                                                  new _VideoPlayer(
                                                      videoModel: videoModel),
                                        ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

class _VideoModel extends Model {
  final MediaPlayerController controller;
  Duration duration = Duration.zero;
  Duration progress = Duration.zero;
  bool playing = false;
  bool showing = false;
  Timer _progressTimer;

  _VideoModel({this.controller}) {
    controller.addListener(() {
      if (duration != controller.duration) {
        duration = controller.duration;
        notifyListeners();
      }
      if (progress != controller.progress) {
        progress = controller.progress;
        notifyListeners();
      }
      if (playing != controller.playing) {
        playing = controller.playing;
        notifyListeners();
      }
    });
  }

  void toggleVideo() {
    showing = !showing;
    if (!showing) {
      _resetPlayingState();
    } else {
      controller.play();
      playing = true;
    }
    notifyListeners();
  }

  void hideVideo() {
    if (showing != false) {
      showing = false;
      _resetPlayingState();
      notifyListeners();
    }
  }

  void _resetPlayingState() {
    controller
      ..pause()
      ..seek(Duration.zero);
    progress = Duration.zero;
    playing = false;
  }

  void togglePlayPause() {
    if (playing) {
      controller.pause();
      playing = false;
    } else {
      controller.play();
      playing = true;
    }
    notifyListeners();
  }

  void skipBack() {
    Duration targetSeek = progress - _kVideoSkipAmount;
    if (targetSeek < Duration.zero) {
      targetSeek = Duration.zero;
    }
    if (progress != targetSeek) {
      controller.seek(targetSeek);
      progress = targetSeek;
      notifyListeners();
    }
  }

  void skipForward() {
    Duration targetSeek = progress + _kVideoSkipAmount;
    if (targetSeek > duration) {
      targetSeek = duration;
    }
    if (progress != targetSeek) {
      controller.seek(targetSeek);
      progress = targetSeek;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (playing && _progressTimer == null) {
      _progressTimer = new Timer.periodic(
        _kVideoProgressTimeout,
        (_) {
          if (progress != controller.progress) {
            progress = controller.progress;
            notifyListeners();
          }
        },
      );
    } else if (!playing) {
      _progressTimer?.cancel();
      _progressTimer = null;
    }
  }
}

class _VideoPlayer extends StatelessWidget {
  final _VideoModel videoModel;

  const _VideoPlayer({this.videoModel});

  @override
  Widget build(BuildContext context) => new Offstage(
        offstage: !videoModel.showing,
        child: new PhysicalModel(
          color: Colors.black,
          elevation: _kVideoPlayerElevation,
          borderRadius: _kVideoPlayerBorderRadius,
          child: new GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Do nothing
            },
            child: new Column(
              children: <Widget>[
                new Expanded(
                  child: new _Video(videoModel: videoModel),
                ),
                new Container(
                  height: _kVideoPlayerButtonHeight,
                  child: new Stack(
                    children: <Widget>[
                      new Positioned.fill(
                        child: new _VideoControls(
                          videoModel: videoModel,
                        ),
                      ),
                      new Positioned(
                        top: 0.0,
                        left: 0.0,
                        right: 0.0,
                        height: _kVideoPlayerProgressBarHeight,
                        child: new _VideoProgress(
                          videoModel: videoModel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Video extends StatelessWidget {
  final _VideoModel videoModel;

  const _Video({this.videoModel});

  @override
  Widget build(BuildContext context) => new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (videoModel.controller.videoViewConnection != null) {
            videoModel.togglePlayPause();
          }
        },
        child: videoModel.controller.videoViewConnection == null
            ? new Center(child: new FuchsiaSpinner())
            : new ChildView(
                connection: videoModel.controller.videoViewConnection,
              ),
      );
}

class _VideoControls extends StatelessWidget {
  final _VideoModel videoModel;

  const _VideoControls({this.videoModel});

  @override
  Widget build(BuildContext context) => new Container(
        margin: const EdgeInsets.symmetric(
          horizontal: _kVideoPlayerTextHorizontalMargin,
        ),
        child: new Row(
          children: <Widget>[
            new Expanded(
              child: new Align(
                alignment: FractionalOffset.topLeft,
                child: new _VideoTime(time: videoModel.progress),
              ),
            ),
            new _VideoControlButton(
              onTap: videoModel.skipBack,
              icon: Icons.fast_rewind,
            ),
            new _VideoControlButton(
              onTap: videoModel.togglePlayPause,
              icon: videoModel.playing ? Icons.pause : Icons.play_arrow,
            ),
            new _VideoControlButton(
              onTap: videoModel.skipForward,
              icon: Icons.fast_forward,
            ),
            new Expanded(
              child: new Align(
                alignment: FractionalOffset.topRight,
                child: new _VideoTime(time: videoModel.duration),
              ),
            ),
          ],
        ),
      );
}

class _VideoTime extends StatelessWidget {
  final Duration time;

  const _VideoTime({this.time});

  @override
  Widget build(BuildContext context) => new Container(
        margin: const EdgeInsets.only(
          top: _kVideoPlayerTextTopMargin,
        ),
        child: new Text(
          _toTimeString(time),
          style: new TextStyle(
            fontSize: _kVideoPlayerTextSize,
            color: Colors.white,
            fontFamily: 'RobotoRegular',
          ),
        ),
      );

  String _toTimeString(Duration duration) {
    String secondsString = duration.inSeconds % 60 < 10
        ? '0${duration.inSeconds % 60}'
        : '${duration.inSeconds % 60}';
    return '${duration.inMinutes}:$secondsString';
  }
}

class _VideoControlButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const _VideoControlButton({this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: new Container(
          width: _kVideoPlayerButtonWidth,
          child: new Center(
            child: new Icon(
              icon,
              size: _kVideoPlayerIconSize,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _VideoProgress extends StatelessWidget {
  final _VideoModel videoModel;

  const _VideoProgress({this.videoModel});

  @override
  Widget build(BuildContext context) => new Align(
        alignment: FractionalOffset.centerLeft,
        child: new FractionallySizedBox(
          heightFactor: 1.0,
          widthFactor: videoModel.duration == Duration.zero
              ? 0.0
              : videoModel.progress.inMilliseconds >
                      videoModel.duration.inMilliseconds
                  ? 1.0
                  : videoModel.progress.inMilliseconds /
                      videoModel.duration.inMilliseconds,
          child: new Container(
            color: Colors.white,
          ),
        ),
      );
}

class _AutoMagicButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new PhysicalModel(
        shape: BoxShape.circle,
        color: _kAutoMagicButtonBackgroundColor,
        elevation: _kAutoMagicElevation,
        child: new Center(
          child: new Icon(
            Icons.create,
            color: Colors.white,
            size: _kAutoMagicIconSize,
          ),
        ),
      );
}

class _AlbumMaker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new PhysicalModel(
        borderRadius: _kAlbumMakerBorderRadius,
        color: _kAlbumMakerBackgroundColor,
        elevation: _kAlbumMakerElevation,
        child: new Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Search box.
            new Positioned.fill(
              top: _kSearchBoxTopOffset,
              child: new Align(
                alignment: FractionalOffset.topCenter,
                child: new _SearchBox(),
              ),
            ),

            // Images.
            new Positioned.fill(
              top: _kSearchBoxTopOffset + _kSearchBoxHeight / 2.0,
              child: new Align(
                alignment: FractionalOffset.topCenter,
                child: new Container(
                  width: _kAlbumMakerImageWidth,
                  child: new Column(children: <Widget>[
                    new PhysicalModel(
                      color: _kAlbumMakerBackgroundColor,
                      elevation: _kElevationStep,
                      child: new Image.asset(
                        'packages/perspective/res/module-a-photos/'
                            '1-sea-withtext.png',
                      ),
                    ),
                    new Container(height: _kAlbumMakerImageMargin),
                    new PhysicalModel(
                      color: _kAlbumMakerBackgroundColor,
                      elevation: _kElevationStep,
                      child: new Image.asset(
                        'packages/perspective/res/module-a-photos/'
                            '2-pano-withtext.png',
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // The sun.
            new Positioned.fill(
              bottom: _kSunBottomOffset,
              child: new Align(
                alignment: FractionalOffset.bottomCenter,
                child: const _Sun(elevation: _kSunRelativeElevation),
              ),
            ),
          ],
        ),
      );
}

class _PhotoList extends StatelessWidget {
  final VoidCallback onVideoTapped;

  const _PhotoList({this.onVideoTapped});

  @override
  Widget build(BuildContext context) => new PhysicalModel(
        borderRadius: _kPhotoListBorderRadius,
        color: _kPhotoListBackgroundColor,
        elevation: _kPhotoListElevation,
        child: new Stack(
          children: <Widget>[
            new Positioned.fill(
              left: _kPhotoListHorizontalMargin,
              right: _kPhotoListHorizontalMargin,
              child: new ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: _kPhotoListTitleHeight + _kPhotoListPhotoMargin,
                  bottom: _kPhotoListPhotoMargin,
                ),
                itemCount: 8,
                itemBuilder: (BuildContext context, int index) => new Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: _kPhotoListPhotoMargin / 2.0,
                      ),
                      child: _photoBuilder(index),
                    ),
              ),
            ),
            new Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              height: _kPhotoListTitleHeight,
              child: new _PhotoListHeader(),
            ),
          ],
        ),
      );

  Widget _photoBuilder(int index) {
    switch (index) {
      case 0:
        return new Image.asset(
          'packages/perspective/res/module-b-gallery-photos/1.png',
          fit: BoxFit.fitWidth,
        );
      case 1:
        return new Image.asset(
          'packages/perspective/res/module-b-gallery-photos/2.png',
          fit: BoxFit.fitWidth,
        );
      case 2:
        return new Stack(
          children: <Widget>[
            new Image.asset(
              'packages/perspective/res/module-b-gallery-photos/3.png',
              fit: BoxFit.fitWidth,
            ),
            new Positioned(
              left: _kPhotoListCheckInset,
              bottom: _kPhotoListCheckInset,
              width: _kPhotoListCheckSize,
              height: _kPhotoListCheckSize,
              child: new PhysicalModel(
                shape: BoxShape.circle,
                color: _kPhotoListCheckBackgroundColor,
                child: new Icon(
                  Icons.check,
                  color: _kPhotoListCheckIconColor,
                  size: _kPhotoListCheckSize,
                ),
              ),
            )
          ],
        );
      case 3:
        return new GestureDetector(
          onTap: onVideoTapped,
          child: new Stack(
            children: <Widget>[
              new Image.asset(
                'packages/perspective/res/module-b-gallery-photos/4.png',
                fit: BoxFit.fitWidth,
              ),
              new Positioned.fill(
                child: new Center(
                  child: new Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: _kPhotoListVideoIconSize,
                  ),
                ),
              )
            ],
          ),
        );
      case 4:
        return new Container(
          height: _kPhotoListQuadPictureHeight,
          child: new Row(
            children: <Widget>[
              new Flexible(
                child: new Column(
                  children: <Widget>[
                    new Expanded(
                      child: new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '5.png',
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    new Container(height: _kPhotoListPhotoMargin),
                    new Expanded(
                      child: new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '7.png',
                        fit: BoxFit.fitWidth,
                      ),
                    )
                  ],
                ),
              ),
              new Container(width: _kPhotoListPhotoMargin),
              new Flexible(
                child: new Column(
                  children: <Widget>[
                    new Expanded(
                      child: new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '6.png',
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    new Container(height: _kPhotoListPhotoMargin),
                    new Expanded(
                      child: new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '8.png',
                        fit: BoxFit.fitWidth,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      case 5:
        return new Image.asset(
          'packages/perspective/res/module-b-gallery-photos/9.png',
          fit: BoxFit.fitWidth,
        );
      case 6:
        return new Image.asset(
          'packages/perspective/res/module-b-gallery-photos/10.png',
          fit: BoxFit.fitWidth,
        );
      case 7:
      default:
        return new Image.asset(
          'packages/perspective/res/module-b-gallery-photos/11.png',
          fit: BoxFit.fitWidth,
        );
    }
  }
}

class _PhotoListHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new PhysicalModel(
        elevation: _kPhotoListTitleRelativeElevation,
        color: _kPhotoListTitleColor,
        child: new Stack(
          children: <Widget>[
            new Align(
              alignment: FractionalOffset.centerLeft,
              child: new Padding(
                padding: const EdgeInsets.only(
                  left: _kPhotoListTitleLeftPadding,
                ),
                child: new Text(
                  'Capture.',
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: _kPhotoListTitleFontSize,
                    fontFamily: 'RobotoMedium',
                  ),
                ),
              ),
            ),
            new Align(
              alignment: FractionalOffset.centerRight,
              child: new Padding(
                padding: const EdgeInsets.only(
                  right: _kPhotoListTitleRightPadding,
                ),
                child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new Text(
                      'French Polynesia',
                      style: new TextStyle(
                        color: Colors.white,
                        fontSize: _kPhotoListDescriptionFontSize,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    new Text(
                      'June 2017',
                      style: new TextStyle(
                        color: Colors.white,
                        fontSize: _kPhotoListDescriptionFontSize,
                        fontFamily: 'RobotoRegular',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _SearchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new PhysicalModel(
        borderRadius: _kSearchBoxBorderRadius,
        color: _kSearchBoxBackgroundColor,
        elevation: _kSearchBoxRelativeElevation,
        child: new Container(
          width: _kSearchBoxWidth,
          height: _kSearchBoxHeight,
          child: new Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kSearchBoxHorizontalMargin,
            ),
            child: new Stack(
              children: <Widget>[
                new Align(
                  alignment: FractionalOffset.centerLeft,
                  child: new Row(
                    children: <Widget>[
                      new Icon(
                        Icons.menu,
                        size: _kSearchBoxIconSize,
                        color: _kSearchBoxTextColor,
                      ),
                      new Container(width: _kSearchBoxHorizontalMargin),
                      new Text(
                        'Story Book',
                        style: new TextStyle(
                          fontFamily: 'RobotoRegular',
                          fontSize: _kSearchBoxTextSize,
                          color: _kSearchBoxTextColor,
                        ),
                      )
                    ],
                  ),
                ),
                new Align(
                  alignment: FractionalOffset.centerRight,
                  child: new Icon(
                    Icons.search,
                    size: _kSearchBoxIconSize,
                    color: _kSearchBoxTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SunRay extends StatelessWidget {
  final double elevation;

  const _SunRay({this.elevation});

  @override
  Widget build(BuildContext context) => new PhysicalModel(
        color: _kSunColor,
        elevation: elevation,
        child: const SizedBox(
          width: _kSunRayWidth,
          height: _kSunRayHeight,
        ),
      );
}

class _Sun extends StatelessWidget {
  final double elevation;

  const _Sun({this.elevation});

  @override
  Widget build(BuildContext context) => new SizedBox(
        width: _kSunDiameter,
        height: _kSunDiameter,
        child: new Stack(
          children: <Widget>[
            // Top ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  0.0,
                  _kSunRayOffset,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.pi / 2.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),

            // Bottom ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  0.0,
                  -_kSunRayOffset,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.pi / 2.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),

            // Right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  _kSunRayOffset,
                  0.0,
                  0.0,
                ),
                child: new _SunRay(elevation: elevation),
              ),
            ),

            // Left ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  -_kSunRayOffset,
                  0.0,
                  0.0,
                ),
                child: new _SunRay(elevation: elevation),
              ),
            ),

            // Sun.
            new Align(
              alignment: FractionalOffset.center,
              child: new PhysicalModel(
                color: _kSunColor,
                elevation: elevation,
                shape: BoxShape.circle,
                child: const SizedBox(
                  width: _kSunCenterDiameter,
                  height: _kSunCenterDiameter,
                ),
              ),
            ),

            // Bottom right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  _kSunRayOffset * _kSqrt2,
                  _kSunRayOffset * _kSqrt2,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.pi / 4.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),

            // Top left ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  -_kSunRayOffset * _kSqrt2,
                  -_kSunRayOffset * _kSqrt2,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(math.pi / 4.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),

            // Top right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  _kSunRayOffset * _kSqrt2,
                  -_kSunRayOffset * _kSqrt2,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(3.0 * math.pi / 4.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),

            // Top right ray.
            new Align(
              alignment: FractionalOffset.center,
              child: new Transform(
                alignment: FractionalOffset.center,
                transform: new Matrix4.translationValues(
                  -_kSunRayOffset * _kSqrt2,
                  _kSunRayOffset * _kSqrt2,
                  0.0,
                ),
                child: new Transform(
                  alignment: FractionalOffset.center,
                  transform: new Matrix4.rotationZ(3.0 * math.pi / 4.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),
          ],
        ),
      );
}

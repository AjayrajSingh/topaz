// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

const double _kAlbumMakerElevation = 2 * _kElevationStep;
const double _kAutoMagicElevation = 16 * _kElevationStep;
const double _kPhotoListElevation = 4 * _kElevationStep;

// Relative to _kAlbumMakerElevation
const double _kSunRelativeElevation = 5 * _kElevationStep;

// Relative to _kPhotoListElevation
const double _kPhotoListTitleRelativeElevation = 4 * _kElevationStep;

// Relative to _kAlbumMakerElevation
const double _kSearchBoxRelativeElevation = 3 * _kElevationStep;

final BorderRadius _kAlbumMakerBorderRadius = new BorderRadius.circular(16.0);
final BorderRadius _kPhotoListBorderRadius = new BorderRadius.circular(16.0);
final BorderRadius _kSearchBoxBorderRadius = new BorderRadius.circular(8.0);

const Color _kAutoMagicButtonBackgroundColor = const Color(0xFF4A78C0);
final Color _kAlbumMakerBackgroundColor = Colors.grey[50];
final Color _kPhotoListBackgroundColor = Colors.grey[50];
final Color _kPhotoListCheckBackgroundColor = Colors.grey[900];
final Color _kPhotoListCheckIconColor = Colors.grey[100];
final Color _kPhotoListTitleColor = Colors.grey[900];
final Color _kSearchBoxBackgroundColor = Colors.grey[50];
final Color _kSearchBoxTextColor = Colors.grey[600];
final Color _kSunColor = Colors.yellow;

Future<Null> main() async {
  runApp(
    new Stack(
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
          child: new _PhotoList(),
        ),

        // Auto Magic Button.
        new Positioned(
          right: _kPhotoListWidth - _kAutoMagicHorizontalOverlap,
          bottom: _kAutoMagicBottomOffset,
          width: _kAutoMagicSize,
          height: _kAutoMagicSize,
          child: new _AutoMagicButton(),
        ),
      ],
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
                child: new _Sun(elevation: _kSunRelativeElevation),
              ),
            ),
          ],
        ),
      );
}

class _PhotoList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new PhysicalModel(
        borderRadius: _kPhotoListBorderRadius,
        color: _kPhotoListBackgroundColor,
        elevation: _kPhotoListElevation,
        child: new Stack(children: <Widget>[
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
              itemBuilder: (BuildContext context, int index) {
                Function builder = (int index) {
                  switch (index) {
                    case 0:
                      return new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '1.png',
                        fit: BoxFit.fitWidth,
                      );
                    case 1:
                      return new Image.asset(
                        'packages/perspective/res/module-b-gallery-photos/'
                            '2.png',
                        fit: BoxFit.fitWidth,
                      );
                    case 2:
                      return new Stack(
                        children: <Widget>[
                          new Image.asset(
                            'packages/perspective/res/module-b-gallery-photos/'
                                '3.png',
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
                        onTap: () {
                          // TODO: Launch a video
                        },
                        child: new Stack(
                          children: <Widget>[
                            new Image.asset(
                              'packages/perspective/res/'
                                  'module-b-gallery-photos/4.png',
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
                                      'packages/perspective/res/'
                                          'module-b-gallery-photos/'
                                          '5.png',
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                  new Container(height: _kPhotoListPhotoMargin),
                                  new Expanded(
                                    child: new Image.asset(
                                      'packages/perspective/res/'
                                          'module-b-gallery-photos/'
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
                                      'packages/perspective/res/'
                                          'module-b-gallery-photos/'
                                          '6.png',
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                  new Container(height: _kPhotoListPhotoMargin),
                                  new Expanded(
                                    child: new Image.asset(
                                      'packages/perspective/res/'
                                          'module-b-gallery-photos/'
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
                        'packages/perspective/res/'
                            'module-b-gallery-photos/9.png',
                        fit: BoxFit.fitWidth,
                      );
                    case 6:
                      return new Image.asset(
                        'packages/perspective/res/'
                            'module-b-gallery-photos/10.png',
                        fit: BoxFit.fitWidth,
                      );
                    case 7:
                    default:
                      return new Image.asset(
                        'packages/perspective/res/'
                            'module-b-gallery-photos/11.png',
                        fit: BoxFit.fitWidth,
                      );
                  }
                };
                return new Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: _kPhotoListPhotoMargin / 2.0,
                  ),
                  child: builder(index),
                );
              },
            ),
          ),
          new Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            height: _kPhotoListTitleHeight,
            child: new PhysicalModel(
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
            ),
          ),
        ]),
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

  _SunRay({this.elevation});

  @override
  Widget build(BuildContext context) => new PhysicalModel(
        color: _kSunColor,
        elevation: elevation,
        child: new SizedBox(
          width: _kSunRayWidth,
          height: _kSunRayHeight,
        ),
      );
}

class _Sun extends StatelessWidget {
  final double elevation;

  _Sun({this.elevation});

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
                  transform: new Matrix4.rotationZ(math.PI / 2.0),
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
                  transform: new Matrix4.rotationZ(math.PI / 2.0),
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
                child: new SizedBox(
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
                  transform: new Matrix4.rotationZ(math.PI / 4.0),
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
                  transform: new Matrix4.rotationZ(math.PI / 4.0),
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
                  transform: new Matrix4.rotationZ(3.0 * math.PI / 4.0),
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
                  transform: new Matrix4.rotationZ(3.0 * math.PI / 4.0),
                  child: new _SunRay(elevation: elevation),
                ),
              ),
            ),
          ],
        ),
      );
}

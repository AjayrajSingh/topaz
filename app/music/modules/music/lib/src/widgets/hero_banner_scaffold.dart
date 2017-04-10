// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'loading_status.dart';

/// This is the height that the Hero Banner should take up (not including the
/// background overflow).
const double _kHeroBannerHeight = 200.0;

/// Top and bottom padding given to the banner, this does not take into account
/// the [_kHeroBannerBackgroundOverflow] which is not considered in the "height"
/// of the banner.
const double _kHeroBannerVerticalPadding = 24.0;

/// This is how many DPs the header background should stretch down beyond just
/// the header content
const double _kHeroBannerBackgroundOverflow = 96.0;

/// Size (height and width) of the main playlist image
const double _kHeroImageSize = 224.0;

/// The amount of horizontal padding given to the header region with respect to
/// the size of the main content.
const double _kHeroBannerHorizontalPadding = 52.0;

/// The maximum width of the main content section below the header.
const double _kBodyMaxWidth = 1000.0;

/// The mininum height of the body section, primarily used to reduce "flow jank"
/// during the transition from loading to completed states.
const double _kMinBodyHeight = 200.0;

/// Default background color used behind the body
final Color _kDefaultBackgroundColor = Colors.grey[300];

/// Color for default failure message
final Color _kFailureTextColor = Colors.grey[500];

/// Scaffold for typical Music layouts that will include:
///   1. A Hero Banner
///   2. A Hero Image that overlaps both the Banner and Body
///   3. A Body where the main content will reside
class HeroBannerScaffold extends StatelessWidget {
  /// Background color for the banner
  ///
  /// Defaults to the primary color of the theme
  final Color heroBannerBackgroundColor;

  /// Background color used behind the body
  ///
  /// Defaults to Grey 300
  final Color backgroundColor;

  /// Child Widget(content) that goes inside the hero banner section
  final Widget heroBanner;

  /// Child Widget (content) that goes inside the hero image section
  final Widget heroImage;

  /// Child Widget (content) that goes inside the main body section
  final Widget body;

  /// Loading Status of the content for this scaffold
  final LoadingStatus loadingStatus;

  /// Constructor
  HeroBannerScaffold({
    Key key,
    this.heroBannerBackgroundColor,
    this.backgroundColor,
    this.loadingStatus: LoadingStatus.completed,
    this.heroBanner,
    this.heroImage,
    this.body,
  })
      : super(key: key);

  Widget _buildHeroBanner(Color backgroundColor) {
    return new Container(
      height: _kHeroBannerHeight + _kHeroBannerBackgroundOverflow,
      color: backgroundColor,
      alignment: FractionalOffset.topCenter,
      padding: const EdgeInsets.only(
        top: _kHeroBannerVerticalPadding,
      ),
      child: new Container(
        constraints: new BoxConstraints(
          maxWidth: _kBodyMaxWidth - 2 * _kHeroBannerHorizontalPadding,
        ),
        padding: const EdgeInsets.only(left: _kHeroImageSize + 32.0),
        height: _kHeroBannerHeight - (_kHeroBannerVerticalPadding * 2),
        child: loadingStatus == LoadingStatus.completed
            ? heroBanner ?? new Container()
            : null,
      ),
    );
  }

  Widget _buildHeroImage() {
    return new Align(
      alignment: FractionalOffset.topCenter,
      child: new Container(
        margin: const EdgeInsets.only(top: _kHeroBannerVerticalPadding),
        constraints: new BoxConstraints(
          maxWidth: _kBodyMaxWidth - 2 * _kHeroBannerHorizontalPadding,
        ),
        alignment: FractionalOffset.topLeft,
        child: new Material(
          elevation: 6,
          type: MaterialType.card,
          color: Colors.white,
          child: new Container(
            margin: const EdgeInsets.all(4.0),
            child: new Container(
              width: _kHeroImageSize,
              height: _kHeroImageSize,
              child: loadingStatus == LoadingStatus.completed
                  ? heroImage ?? new Container()
                  : new Container(color: Colors.grey[300]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget child;
    switch (loadingStatus) {
      case LoadingStatus.inProgress:
        child = new Center(
          child: new CircularProgressIndicator(
            value: null,
            valueColor: new AlwaysStoppedAnimation<Color>(
              heroBannerBackgroundColor,
            ),
          ),
        );
        break;
      case LoadingStatus.failed:
        child = new Center(
          child: new Column(
            children: <Widget>[
              new Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: new Icon(
                  Icons.sentiment_dissatisfied,
                  size: 48.0,
                  color: _kFailureTextColor,
                ),
              ),
              new Text(
                'Content failed to load',
                style: new TextStyle(
                  fontSize: 16.0,
                  color: _kFailureTextColor,
                ),
              ),
            ],
          ),
        );
        break;
      case LoadingStatus.completed:
        child = body ?? new Container();
        break;
    }
    return new Container(
      margin: const EdgeInsets.only(
        top: _kHeroBannerHeight,
        bottom: 32.0,
      ),
      constraints: new BoxConstraints(minHeight: _kMinBodyHeight),
      alignment: FractionalOffset.topCenter,
      child: new Material(
        elevation: 4,
        type: MaterialType.card,
        color: Colors.white,
        child: new Container(
          constraints: new BoxConstraints(
            maxWidth: _kBodyMaxWidth,
          ),
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Container(
                height: _kHeroBannerBackgroundOverflow,
                decoration: new BoxDecoration(
                  border: new Border(
                      bottom: new BorderSide(
                    color: Colors.grey[300],
                  )),
                ),
              ),
              new Container(
                constraints: new BoxConstraints(
                  minHeight: _kMinBodyHeight,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Container(
      color: backgroundColor ?? _kDefaultBackgroundColor,
      child: new Stack(
        children: <Widget>[
          new Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: _buildHeroBanner(
              heroBannerBackgroundColor ?? theme.primaryColor,
            ),
          ),
          _buildBody(),
          _buildHeroImage(),
        ],
      ),
    );
  }
}

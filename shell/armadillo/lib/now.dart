// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'minimized_now_bar.dart';
import 'now_minimization_model.dart';
import 'now_user_and_maximized_info.dart';
import 'quick_settings.dart';
import 'quick_settings_progress_model.dart';
import 'size_model.dart';
import 'story_drag_transition_model.dart';

/// The distance above the lowest point we can scroll down to when
/// recents scroll offset is 0.0.
const double _kRestingDistanceAboveLowestPoint = 80.0;

/// When the recent list's scrollOffset exceeds this value we minimize [Now].
const double _kNowMinimizationScrollOffsetThreshold = 120.0;

/// When the recent list's scrollOffset exceeds this value we hide quick
/// settings [Now].
const double _kNowQuickSettingsHideScrollOffsetThreshold = 16.0;

const double _kQuickSettingsHorizontalPadding = 16.0;

const double _kQuickSettingsInnerHorizontalPadding = 16.0;

const double _kMaxQuickSettingsBackgroundWidth = 700.0;

/// The overscroll amount which must occur before now begins to grow in height.
const double _kOverscrollDelayOffset = 0.0;

/// The speed multiple at which now increases in height when overscrolling.
const double _kScrollFactor = 0.8;

// initialized in showQuickSettings
final double _kQuickSettingsMaximizedHeight = 200.0;

/// Shows the user, the user's context, and important settings.  When minimized
/// also shows an affordance for seeing missed interruptions.
class Now extends StatefulWidget {
  /// How much to shift the quick settings vertically when shown.
  final double quickSettingsHeightBump;

  /// Called when [Now]'s center button is tapped while minimized.
  final VoidCallback onMinimizedTap;

  /// Called when [Now]'s center button is long pressed while minimized.
  final VoidCallback onMinimizedLongPress;

  /// Called when [Now]'s quick settings are maximized.
  final VoidCallback onQuickSettingsMaximized;

  /// Called when the user releases their finger while overscrolled past a
  /// certain threshold and/or overscrolling with a certain velocity.
  final VoidCallback onOverscrollThresholdRelease;

  /// Called when a vertical drag occurs on [Now] when in its fully minimized
  /// bar state.
  final GestureDragUpdateCallback onBarVerticalDragUpdate;

  /// Called when a vertical drag ends on [Now] when in its fully minimized bar
  /// state.
  final GestureDragEndCallback onBarVerticalDragEnd;

  /// Called when the user selects log out.
  final VoidCallback onLogoutSelected;

  /// Called when the user selects log out and clear the ledger.
  final VoidCallback onClearLedgerSelected;

  /// Called when the user taps the user context.
  final VoidCallback onUserContextTapped;

  /// Called when minimized context is tapped.
  final VoidCallback onMinimizedContextTapped;

  /// Constructor.
  Now({
    Key key,
    this.quickSettingsHeightBump,
    this.onMinimizedTap,
    this.onMinimizedLongPress,
    this.onQuickSettingsMaximized,
    this.onBarVerticalDragUpdate,
    this.onBarVerticalDragEnd,
    this.onOverscrollThresholdRelease,
    this.onLogoutSelected,
    this.onClearLedgerSelected,
    this.onUserContextTapped,
    this.onMinimizedContextTapped,
  })
      : super(key: key);

  @override
  NowState createState() => new NowState();
}

/// Controls the animations for maximizing and minimizing, showing and hiding
/// quick settings, and vertically shifting as the story list is scrolled.
class NowState extends State<Now> {
  final ValueNotifier<double> _recentsScrollOffset =
      new ValueNotifier<double>(0.0);

  /// scroll offset affects the bottom padding of the user and text elements
  /// as well as the overall height of [Now] while maximized.
  double _lastRecentsScrollOffset = 0.0;

  /// Sets the [scrollOffset] of the story list tracked by [Now].
  void onRecentsScrollOffsetChanged(double scrollOffset, bool ignore) {
    _recentsScrollOffset.value =
        scrollOffset - SizeModel.of(context).storyListTopPadding;
    if (ignore) {
      return;
    }
    if (scrollOffset > _kNowMinimizationScrollOffsetThreshold &&
        _lastRecentsScrollOffset < scrollOffset) {
      NowMinimizationModel.of(context).minimize();
      QuickSettingsProgressModel.of(context).hide();
    } else if (scrollOffset < _kNowMinimizationScrollOffsetThreshold &&
        _lastRecentsScrollOffset > scrollOffset) {
      NowMinimizationModel.of(context).maximize();
    }
    // When we're past the quick settings threshold and are
    // scrolling further, hide quick settings.
    if (scrollOffset > _kNowQuickSettingsHideScrollOffsetThreshold &&
        _lastRecentsScrollOffset < scrollOffset) {
      QuickSettingsProgressModel.of(context).hide();
    }
    _lastRecentsScrollOffset = scrollOffset;
  }

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<StoryDragTransitionModel>(
        builder: (
          BuildContext context,
          Widget child,
          StoryDragTransitionModel storyDragTransitionModel,
        ) =>
            new Offstage(
              offstage: storyDragTransitionModel.value == 1.0,
              child: new Opacity(
                opacity: lerpDouble(
                  1.0,
                  0.0,
                  storyDragTransitionModel.value,
                ),
                child: child,
              ),
            ),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            BuildContext context,
            Widget child,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new ScopedModelDescendant<NowMinimizationModel>(
                builder: (
                  BuildContext context,
                  Widget child,
                  NowMinimizationModel nowMinimizationModel,
                ) =>
                    _buildNow(
                      context,
                      quickSettingsProgressModel,
                      nowMinimizationModel,
                    ),
              ),
        ),
      );

  Widget _buildNow(
    BuildContext context,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      new Align(
        alignment: FractionalOffset.bottomCenter,
        child: new ScopedModelDescendant<SizeModel>(
          builder: (
            BuildContext context,
            Widget child,
            SizeModel sizeModel,
          ) =>
              new AnimatedBuilder(
                animation: _recentsScrollOffset,
                builder: (BuildContext context, Widget child) => new Container(
                      height: _getNowHeight(
                        quickSettingsProgressModel,
                        nowMinimizationModel,
                        sizeModel,
                        _recentsScrollOffset.value,
                      ),
                      child: child,
                    ),
                child: new Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    // Quick Settings Background.
                    new Positioned(
                      left: _kQuickSettingsHorizontalPadding,
                      right: _kQuickSettingsHorizontalPadding,
                      top: _getQuickSettingsBackgroundTopOffset(
                        sizeModel,
                        quickSettingsProgressModel,
                        nowMinimizationModel,
                      ),
                      child: new Center(
                        child: new Container(
                          height: _getQuickSettingsBackgroundHeight(
                            sizeModel,
                            quickSettingsProgressModel,
                            nowMinimizationModel,
                          ),
                          width: _getQuickSettingsBackgroundWidth(
                            sizeModel,
                            quickSettingsProgressModel,
                            nowMinimizationModel,
                          ),
                          decoration: new BoxDecoration(
                            color: Colors.white,
                            borderRadius: new BorderRadius.circular(
                              quickSettingsProgressModel.backgroundBorderRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // User Image, User Context Text, and Important Information when maximized.
                    new Positioned(
                      left: _kQuickSettingsHorizontalPadding,
                      right: _kQuickSettingsHorizontalPadding,
                      top: _getUserImageTopOffset(
                        sizeModel,
                        quickSettingsProgressModel,
                        nowMinimizationModel,
                      ),
                      child: new Center(
                        child: new Column(
                          children: <Widget>[
                            new NowUserAndMaximizedContext(
                              onUserContextTapped: widget.onUserContextTapped,
                              onUserTapped: () {
                                if (!quickSettingsProgressModel.showing) {
                                  _showQuickSettings();
                                } else {
                                  quickSettingsProgressModel.hide();
                                }
                              },
                            ),
                            new Container(height: 32.0),
                            // Quick Settings
                            _buildQuickSettings(
                              quickSettingsProgressModel,
                              nowMinimizationModel,
                              sizeModel,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // User Context Text and Important Information when minimized.
                    new MinimizedNowBar(),

                    // Minimized button bar gesture detector. Only enabled when
                    // we're nearly fully minimized.
                    _buildMinimizedButtonBarGestureDetector(
                      sizeModel,
                      nowMinimizationModel,
                    ),
                  ],
                ),
              ),
        ),
      );

  Widget _buildQuickSettings(
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
    SizeModel sizeModel,
  ) =>
      new Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: _kQuickSettingsInnerHorizontalPadding, vertical: 8.0),
        child: new Container(
          width: _getQuickSettingsBackgroundWidth(
            sizeModel,
            quickSettingsProgressModel,
            nowMinimizationModel,
          ),
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Divider(
                height: 4.0,
                color: Colors.grey[300].withOpacity(
                  quickSettingsProgressModel.fadeInProgress,
                ),
              ),
              new Container(
                child: new QuickSettings(
                  opacity: quickSettingsProgressModel.fadeInProgress,
                  onLogoutSelected: widget.onLogoutSelected,
                  onClearLedgerSelected: widget.onClearLedgerSelected,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildMinimizedButtonBarGestureDetector(
    SizeModel sizeModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      new Offstage(
        offstage: _getButtonTapDisabled(nowMinimizationModel),
        child: new GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: widget.onBarVerticalDragUpdate,
          onVerticalDragEnd: widget.onBarVerticalDragEnd,
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              new Expanded(
                child: new GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onMinimizedContextTapped?.call();
                  },
                ),
              ),
              new GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMinimizedTap,
                onLongPress: widget.onMinimizedLongPress,
                child: new Container(width: sizeModel.minimizedNowHeight * 4.0),
              ),
              new Expanded(
                child: new GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onMinimizedContextTapped?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      );

  /// Morphs [Now] into its quick settings mode.
  /// This should only be called when [Now] is maximized.
  void _showQuickSettings() {
    if (!_revealingQuickSettings) {
      QuickSettingsProgressModel.of(context).target = 1.0;
      widget.onQuickSettingsMaximized?.call();
    }
  }

  bool get _revealingQuickSettings =>
      QuickSettingsProgressModel.of(context).target == 1.0;

  bool _getButtonTapDisabled(NowMinimizationModel nowMinimizationModel) =>
      nowMinimizationModel.value < 1.0;

  double _getNowHeight(
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
    SizeModel sizeModel,
    double scrollOffset,
  ) =>
      math.max(
          sizeModel.minimizedNowHeight,
          sizeModel.minimizedNowHeight +
              ((sizeModel.maximizedNowHeight - sizeModel.minimizedNowHeight) *
                  (1.0 - nowMinimizationModel.value)) +
              _getQuickSettingsRaiseDistance(quickSettingsProgressModel) +
              _getScrollOffsetHeightDelta(
                scrollOffset,
                quickSettingsProgressModel,
                nowMinimizationModel,
              ));

  double _getUserImageTopOffset(
    SizeModel sizeModel,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      lerpDouble(
        lerpDouble(100.0, 20.0, quickSettingsProgressModel.value),
        ((sizeModel.minimizedNowHeight -
                nowMinimizationModel.userImageDiameter) /
            2.0),
        nowMinimizationModel.value,
      );

  double _getQuickSettingsBackgroundTopOffset(
    SizeModel sizeModel,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      _getUserImageTopOffset(
        sizeModel,
        quickSettingsProgressModel,
        nowMinimizationModel,
      ) +
      ((nowMinimizationModel.userImageDiameter / 2.0) *
          quickSettingsProgressModel.value);

  double _getQuickSettingsBackgroundMaximizedWidth(SizeModel sizeModel) =>
      math.min(_kMaxQuickSettingsBackgroundWidth, sizeModel.screenSize.width) -
      2 * _kQuickSettingsHorizontalPadding;

  double _getQuickSettingsBackgroundWidth(
    SizeModel sizeModel,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      lerpDouble(
        nowMinimizationModel.userImageDiameter,
        _getQuickSettingsBackgroundMaximizedWidth(sizeModel),
        quickSettingsProgressModel.value * (1.0 - nowMinimizationModel.value),
      );

  double _getQuickSettingsBackgroundHeight(
    SizeModel sizeModel,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      lerpDouble(
        nowMinimizationModel.userImageDiameter,
        -_getUserImageTopOffset(
              sizeModel,
              quickSettingsProgressModel,
              nowMinimizationModel,
            ) +
            nowMinimizationModel.userImageDiameter +
            nowMinimizationModel.userImageDiameter +
            nowMinimizationModel.userImageDiameter +
            _getQuickSettingsHeight(quickSettingsProgressModel),
        quickSettingsProgressModel.value * (1.0 - nowMinimizationModel.value),
      );

  double _getQuickSettingsHeight(
    QuickSettingsProgressModel quickSettingsProgressModel,
  ) =>
      quickSettingsProgressModel.value * _kQuickSettingsMaximizedHeight;

  double _getQuickSettingsRaiseDistance(
    QuickSettingsProgressModel quickSettingsProgressModel,
  ) =>
      widget.quickSettingsHeightBump * quickSettingsProgressModel.value;

  double _getScrollOffsetHeightDelta(
    double scrollOffset,
    QuickSettingsProgressModel quickSettingsProgressModel,
    NowMinimizationModel nowMinimizationModel,
  ) =>
      (math.max(
                  -_kRestingDistanceAboveLowestPoint,
                  (scrollOffset > -_kOverscrollDelayOffset &&
                          scrollOffset < 0.0)
                      ? 0.0
                      : (-1.0 *
                              (scrollOffset < 0.0
                                  ? scrollOffset + _kOverscrollDelayOffset
                                  : scrollOffset) *
                              _kScrollFactor) *
                          (1.0 - nowMinimizationModel.value) *
                          (1.0 - quickSettingsProgressModel.value)) *
              1000.0)
          .truncateToDouble() /
      1000.0;
}

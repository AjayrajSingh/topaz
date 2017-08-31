// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/widgets.dart';

import 'context_model.dart';
import 'elevations.dart';
import 'fading_spring_simulation.dart';
import 'important_info.dart';
import 'nothing.dart';
import 'opacity_model.dart';
import 'power_model.dart';
import 'quick_settings.dart';
import 'quick_settings_progress_model.dart';
import 'size_model.dart';
import 'story_drag_transition_model.dart';
import 'user_context_text.dart';

/// Fraction of the minimization animation which should be used for falling away
/// and sliding in of the user context and battery icon.
const double _kFallAwayDurationFraction = 0.35;

/// The distance above the lowest point we can scroll down to when
/// [NowState.scrollOffset] is 0.0.
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

/// If the user releases their finger when overscrolled more than this amount,
/// we snap suggestions open.
const double _kOverscrollAutoSnapThreshold = -250.0;

/// If the user releases their finger when overscrolled more than this amount
/// and  the user dragged their finger at least
/// [_kOverscrollSnapDragDistanceThreshold], we snap suggestions open.
const double _kOverscrollSnapDragThreshold = -50.0;

/// See [_kOverscrollSnapDragThreshold].
const double _kOverscrollSnapDragDistanceThreshold = 200.0;

/// Shows the user, the user's context, and important settings.  When minimized
/// also shows an affordance for seeing missed interruptions.
class Now extends StatefulWidget {
  /// How much to shift the quick settings vertically when shown.
  final double quickSettingsHeightBump;

  /// Called when the quick settings animation progress changes within the range
  /// of 0.0 to 1.0.
  final ValueChanged<double> onQuickSettingsProgressChange;

  /// Called when [Now]'s center button is tapped while minimized.
  final VoidCallback onMinimizedTap;

  /// Called when [Now]'s center button is long pressed while minimized.
  final VoidCallback onMinimizedLongPress;

  /// Called when [Now] is minimized.
  final VoidCallback onMinimize;

  /// Called when [Now] is maximized.
  final VoidCallback onMaximize;

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

  /// Provides story list scrolling information.
  final ScrollController scrollController;

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
    this.onQuickSettingsProgressChange,
    this.onMinimizedTap,
    this.onMinimizedLongPress,
    this.onMinimize,
    this.onMaximize,
    this.onQuickSettingsMaximized,
    this.onBarVerticalDragUpdate,
    this.onBarVerticalDragEnd,
    this.onOverscrollThresholdRelease,
    this.scrollController,
    this.onLogoutSelected,
    this.onClearLedgerSelected,
    this.onUserContextTapped,
    this.onMinimizedContextTapped,
  })
      : super(key: key);

  @override
  NowState createState() => new NowState();
}

/// Spring description used by the minimization and quick settings reveal
/// simulations.
const RK4SpringDescription _kSimulationDesc =
    const RK4SpringDescription(tension: 600.0, friction: 50.0);

const double _kMinimizationSimulationTarget = 400.0;
const double _kQuickSettingsSimulationTarget = 100.0;

/// Controls the animations for maximizing and minimizing, showing and hiding
/// quick settings, and vertically shifting as the story list is scrolled.
class NowState extends TickingState<Now> {
  /// The simulation for the minimization to a bar.
  final RK4SpringSimulation _minimizationSimulation =
      new RK4SpringSimulation(initValue: 0.0, desc: _kSimulationDesc);

  /// The simulation for the inline quick settings reveal.
  final RK4SpringSimulation _quickSettingsSimulation =
      new RK4SpringSimulation(initValue: 0.0, desc: _kSimulationDesc);

  /// The simulation for showing minimized info in the minimized bar.
  final RK4SpringSimulation _minimizedInfoSimulation = new RK4SpringSimulation(
      initValue: _kMinimizationSimulationTarget, desc: _kSimulationDesc);

  final GlobalKey _quickSettingsKey = new GlobalKey();
  final GlobalKey _importantInfoMaximizedKey = new GlobalKey();
  final GlobalKey _userContextTextKey = new GlobalKey();
  final GlobalKey _userImageKey = new GlobalKey();
  final OpacityModel _minimizedInfoOpacityModel = new OpacityModel(0.0);
  FadingSpringSimulation _fadingSpringSimulation;

  /// [scrollOffset] affects the bottom padding of the user and text elements
  /// as well as the overall height of [Now] while maximized.
  double _lastScrollOffset = 0.0;

  // initialized in showQuickSettings
  final double _quickSettingsMaximizedHeight = 200.0;
  double _importantInfoMaximizedHeight = 0.0;
  double _userContextTextHeight = 0.0;
  double _userImageHeight = 0.0;
  double _pointerDownY;

  /// Sets the [scrollOffset] of the story list tracked by [Now].
  set scrollOffset(double scrollOffset) {
    if (scrollOffset > _kNowMinimizationScrollOffsetThreshold &&
        _lastScrollOffset < scrollOffset) {
      minimize();
      hideQuickSettings();
    } else if (scrollOffset < _kNowMinimizationScrollOffsetThreshold &&
        _lastScrollOffset > scrollOffset) {
      maximize();
    }
    // When we're past the quick settings threshold and are
    // scrolling further, hide quick settings.
    if (scrollOffset > _kNowQuickSettingsHideScrollOffsetThreshold &&
        _lastScrollOffset < scrollOffset) {
      hideQuickSettings();
    }
    _lastScrollOffset = scrollOffset;
  }

  @override
  void initState() {
    super.initState();
    _fadingSpringSimulation = new FadingSpringSimulation(
      onChange: _updateMinimizedInfoOpacity,
      tickerProvider: this,
    );
  }

  @override
  void dispose() {
    _fadingSpringSimulation.reset();
    super.dispose();
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
              offstage: storyDragTransitionModel.progress == 1.0,
              child: new Opacity(
                opacity: lerpDouble(
                  1.0,
                  0.0,
                  storyDragTransitionModel.progress,
                ),
                child: child,
              ),
            ),
        child: _buildNow(context),
      );

  Widget _buildNow(BuildContext context) => new Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          new Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (PointerDownEvent event) {
              _pointerDownY = event.position.dy;
            },
            onPointerUp: (PointerUpEvent event) {
              // When the user lifts their finger after overscrolling we may
              // want to snap suggestions open.
              // We will do so if the overscroll is significant or if the user
              // lifted after dragging a certain distance.
              if (widget.scrollController.offset <
                      _kOverscrollAutoSnapThreshold ||
                  (widget.scrollController.offset <
                          _kOverscrollSnapDragThreshold &&
                      _pointerDownY - event.position.dy >
                          _kOverscrollSnapDragDistanceThreshold)) {
                widget.onOverscrollThresholdRelease?.call();
              }
              hideQuickSettings();
            },
          ),
          new Align(
            alignment: FractionalOffset.bottomCenter,
            child: new ScopedModelDescendant<SizeModel>(
              builder: (
                BuildContext context,
                Widget child,
                SizeModel sizeModel,
              ) =>
                  new AnimatedBuilder(
                    animation: widget.scrollController,
                    builder: (BuildContext context, Widget child) =>
                        new Container(
                          height: _getNowHeight(
                            sizeModel,
                            widget.scrollController.offset,
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
                          ),
                          child: new Center(
                            child: new Container(
                              height: _getQuickSettingsBackgroundHeight(
                                sizeModel,
                              ),
                              width: _getQuickSettingsBackgroundWidth(
                                sizeModel,
                              ),
                              decoration: new BoxDecoration(
                                color: Colors.white,
                                borderRadius: new BorderRadius.circular(
                                  _quickSettingsBackgroundBorderRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // User Image, User Context Text, and Important Information when maximized.
                        new Positioned(
                          left: _kQuickSettingsHorizontalPadding,
                          right: _kQuickSettingsHorizontalPadding,
                          top: _getUserImageTopOffset(sizeModel),
                          child: new Center(
                            child: new Column(
                              children: <Widget>[
                                new Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // User Context Text when maximized.
                                    new Expanded(
                                      child: new GestureDetector(
                                        onTap: widget.onUserContextTapped,
                                        behavior: HitTestBehavior.opaque,
                                        child: new Container(
                                          key: _userContextTextKey,
                                          height: _userImageSize,
                                          child: _buildUserContextMaximized(
                                            opacity: _fallAwayOpacity,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // User Profile image
                                    _buildUserImage(),
                                    // Important Information when maximized.
                                    new Expanded(
                                      child: new Container(
                                        key: _importantInfoMaximizedKey,
                                        height: _userImageSize,
                                        child: _buildImportantInfoMaximized(
                                          opacity: _fallAwayOpacity,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Quick Settings
                                new Container(
                                  padding: const EdgeInsets.only(top: 32.0),
                                  child: _buildQuickSettings(sizeModel),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // User Context Text and Important Information when minimized.
                        _buildMinimizedUserContextTextAndImportantInformation(
                          sizeModel,
                        ),

                        // Minimized button bar gesture detector. Only enabled when
                        // we're nearly fully minimized.
                        _buildMinimizedButtonBarGestureDetector(
                          sizeModel,
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      );

  Widget _buildUserImage() => new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_revealingQuickSettings) {
            showQuickSettings();
          } else {
            hideQuickSettings();
          }
        },
        child: new PhysicalModel(
          color: Colors.transparent,
          shape: BoxShape.circle,
          elevation:
              _quickSettingsProgress * Elevations.nowUserQuickSettingsOpen,
          child: new Container(
            key: _userImageKey,
            width: _userImageSize,
            height: _userImageSize,
            foregroundDecoration: new BoxDecoration(
              border: new Border.all(
                color: new Color(0xFFFFFFFF),
                width: _userImageBorderWidth,
              ),
              shape: BoxShape.circle,
            ),
            child: _buildUser(),
          ),
        ),
      );

  Widget _buildQuickSettings(SizeModel sizeModel) => new Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: _kQuickSettingsInnerHorizontalPadding, vertical: 8.0),
        child: new Container(
          width: _getQuickSettingsBackgroundWidth(
            sizeModel,
          ),
          child: new Column(
            key: _quickSettingsKey,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Divider(
                height: 4.0,
                color: Colors.grey[300].withOpacity(
                  _quickSettingsSlideUpProgress,
                ),
              ),
              new Container(
                child: new QuickSettings(
                  opacity: _quickSettingsSlideUpProgress,
                  onLogoutSelected: widget.onLogoutSelected,
                  onClearLedgerSelected: widget.onClearLedgerSelected,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildMinimizedUserContextTextAndImportantInformation(
    SizeModel sizeModel,
  ) =>
      new Align(
        alignment: FractionalOffset.bottomCenter,
        child: new Container(
          height: sizeModel.minimizedNowHeight,
          padding: new EdgeInsets.symmetric(horizontal: 8.0 + _slideInDistance),
          child: new RepaintBoundary(
            child: new ScopedModel<OpacityModel>(
              model: _minimizedInfoOpacityModel,
              child: new Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _buildUserContextMinimized(),
                  _buildImportantInfoMinimized(),
                ],
              ),
            ),
          ),
        ),
      );

  /// Returns a succinct representation of the user's current context.
  Widget _buildUserContextMinimized() => new Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: new ScopedModelDescendant<OpacityModel>(
          builder: (
            BuildContext context,
            Widget child,
            OpacityModel opacityModel,
          ) =>
              new Opacity(
                opacity: opacityModel.opacity,
                child: child,
              ),
          child: new ScopedModelDescendant<ContextModel>(
            builder: (BuildContext context, Widget child, ContextModel model) =>
                new Text('${model.timeOnly}'),
          ),
        ),
      );

  /// Returns a succinct representation of the important information to the
  /// user.
  Widget _buildImportantInfoMinimized() =>
      new ScopedModelDescendant<PowerModel>(
        builder: (
          BuildContext context,
          Widget child,
          PowerModel powerModel,
        ) =>
            !powerModel.hasBattery
                ? Nothing.widget
                : new Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      new Padding(
                        padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                        child: new ScopedModelDescendant<OpacityModel>(
                          builder: (
                            BuildContext context,
                            Widget child,
                            OpacityModel opacityModel,
                          ) =>
                              new Opacity(
                                opacity: opacityModel.opacity,
                                child: child,
                              ),
                          child: new Text(powerModel.batteryText),
                        ),
                      ),
                      new ScopedModelDescendant<OpacityModel>(
                          builder: (
                        BuildContext context,
                        Widget child,
                        OpacityModel opacityModel,
                      ) =>
                              new Image.asset(
                                powerModel.batteryImageUrl,
                                color: Colors.white
                                    .withOpacity(opacityModel.opacity),
                                fit: BoxFit.cover,
                                height: 24.0,
                              )),
                    ],
                  ),
      );

  /// Returns an avatar of the current user.
  Widget _buildUser() => new ScopedModelDescendant<ContextModel>(
        builder: (
          BuildContext context,
          Widget child,
          ContextModel contextModel,
        ) {
          String avatarUrl = _getImageUrl(contextModel.userImageUrl) ?? '';
          String name = contextModel.userName ?? '';
          return avatarUrl.isNotEmpty
              ? new Alphatar.fromNameAndUrl(
                  avatarUrl: avatarUrl,
                  name: name,
                )
              : new Alphatar.fromName(
                  name: name,
                );
        },
      );

  /// Returns a verbose representation of the user's current context.
  Widget _buildUserContextMaximized({double opacity: 1.0}) => new Opacity(
        opacity: opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            _,
            __,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new Transform(
                transform: new Matrix4.translationValues(
                  lerpDouble(
                    -16.0,
                    0.0,
                    opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
                  ),
                  lerpDouble(0.0, 32.0, _quickSettingsProgress),
                  0.0,
                ),
                child: new UserContextText(
                  textColor: Color.lerp(
                    Colors.white,
                    Colors.grey[600],
                    _quickSettingsProgress,
                  ),
                ),
              ),
        ),
      );

  /// Returns a verbose representation of the important information to the user
  /// with the given [opacity].
  Widget _buildImportantInfoMaximized({double opacity: 1.0}) => new Opacity(
        opacity: opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            _,
            __,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new Transform(
                transform: new Matrix4.translationValues(
                  lerpDouble(
                    16.0,
                    0.0,
                    opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
                  ),
                  lerpDouble(
                    0.0,
                    32.0,
                    quickSettingsProgressModel.quickSettingsProgress,
                  ),
                  0.0,
                ),
                child: new ImportantInfo(
                  textColor: Color.lerp(
                    Colors.white,
                    Colors.grey[600],
                    quickSettingsProgressModel.quickSettingsProgress,
                  ),
                ),
              ),
        ),
      );

  String _getImageUrl(String userImageUrl) {
    if (userImageUrl == null) {
      return null;
    }
    Uri uri = Uri.parse(userImageUrl);
    if (uri.queryParameters['sz'] != null) {
      Map<String, dynamic> queryParameters = new Map<String, dynamic>.from(
        uri.queryParameters,
      );
      queryParameters['sz'] = '112';
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri.toString();
  }

  void _updateMinimizedInfoOpacity() {
    _minimizedInfoOpacityModel.opacity =
        _fadingSpringSimulation.opacity * 0.6 * _slideInProgress;
  }

  Widget _buildMinimizedButtonBarGestureDetector(SizeModel sizeModel) =>
      new Offstage(
        offstage: _buttonTapDisabled,
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
                  onTapDown: (_) {
                    _fadingSpringSimulation.fadeIn();
                  },
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
                  onTapDown: (_) {
                    _fadingSpringSimulation.fadeIn();
                  },
                  onTap: () {
                    widget.onMinimizedContextTapped?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      );

  @override
  bool handleTick(double elapsedSeconds) {
    bool continueTicking = false;

    // Tick the minimized info simulation.
    _minimizedInfoSimulation.elapseTime(elapsedSeconds);
    if (!_minimizedInfoSimulation.isDone) {
      continueTicking = true;
    }

    // Tick the minimization simulation.
    if (!_minimizationSimulation.isDone) {
      _minimizationSimulation.elapseTime(elapsedSeconds);
      if (!_minimizationSimulation.isDone) {
        continueTicking = true;
      }
    }

    // Tick the quick settings simulation.
    if (!_quickSettingsSimulation.isDone) {
      _quickSettingsSimulation.elapseTime(elapsedSeconds);
      if (!_quickSettingsSimulation.isDone) {
        continueTicking = true;
      }
      if (widget.onQuickSettingsProgressChange != null) {
        widget.onQuickSettingsProgressChange(_quickSettingsProgress);
      }
      QuickSettingsProgressModel.of(context).quickSettingsProgress =
          _quickSettingsProgress;
    }

    _updateMinimizedInfoOpacity();
    return continueTicking;
  }

  /// Minimizes [Now] to its bar state.
  void minimize() {
    if (!_minimizing) {
      _minimizationSimulation.target = _kMinimizationSimulationTarget;
      _showMinimizedInfo();
      startTicking();
      widget.onMinimize?.call();
    }
  }

  /// Maximizes [Now] to display the user and context text.
  void maximize() {
    if (_minimizing) {
      _minimizationSimulation.target = 0.0;
      startTicking();
      widget.onMaximize?.call();
    }
  }

  /// Morphs [Now] into its quick settings mode.
  /// This should only be called when [Now] is maximized.
  void showQuickSettings() {
    double heightFromKey(GlobalKey key) {
      RenderBox box = key.currentContext.findRenderObject();
      return box.size.height;
    }

    _importantInfoMaximizedHeight = heightFromKey(_importantInfoMaximizedKey);
    _userContextTextHeight = heightFromKey(_userContextTextKey);
    _userImageHeight = heightFromKey(_userImageKey);

    if (!_revealingQuickSettings) {
      _quickSettingsSimulation.target = _kQuickSettingsSimulationTarget;
      startTicking();
      widget.onQuickSettingsMaximized?.call();
    }
  }

  /// Morphs [Now] into its normal mode.
  /// This should only be called when [Now] is maximized.
  void hideQuickSettings() {
    if (_revealingQuickSettings) {
      _quickSettingsSimulation.target = 0.0;
      startTicking();
    }
  }

  void _showMinimizedInfo() {
    _fadingSpringSimulation.fadeIn(force: true);
    _minimizedInfoSimulation.target = _kMinimizationSimulationTarget;
    startTicking();
  }

  double get _quickSettingsProgress =>
      _quickSettingsSimulation.value / _kQuickSettingsSimulationTarget;

  double get _minimizationProgress =>
      _minimizationSimulation.value / _kMinimizationSimulationTarget;

  double get _minimizedInfoProgress =>
      _minimizedInfoSimulation.value / _kMinimizationSimulationTarget;

  bool get _minimizing =>
      _minimizationSimulation.target == _kMinimizationSimulationTarget;

  bool get _revealingQuickSettings =>
      _quickSettingsSimulation.target == _kQuickSettingsSimulationTarget;

  bool get _buttonTapDisabled => _minimizationProgress < 1.0;

  double _getNowHeight(SizeModel sizeModel, double scrollOffset) => math.max(
      sizeModel.minimizedNowHeight,
      sizeModel.minimizedNowHeight +
          ((sizeModel.maximizedNowHeight - sizeModel.minimizedNowHeight) *
              (1.0 - _minimizationProgress)) +
          _quickSettingsRaiseDistance +
          _getScrollOffsetHeightDelta(scrollOffset));

  double get _userImageSize => lerpDouble(56.0, 12.0, _minimizationProgress);

  double get _userImageBorderWidth =>
      lerpDouble(2.0, 6.0, _minimizationProgress);

  double _getUserImageTopOffset(SizeModel sizeModel) =>
      lerpDouble(100.0, 20.0, _quickSettingsProgress) *
          (1.0 - _minimizationProgress) +
      ((sizeModel.minimizedNowHeight - _userImageSize) / 2.0) *
          _minimizationProgress;

  double _getQuickSettingsBackgroundTopOffset(SizeModel sizeModel) =>
      _getUserImageTopOffset(sizeModel) +
      ((_userImageSize / 2.0) * _quickSettingsProgress);

  double get _quickSettingsBackgroundBorderRadius =>
      lerpDouble(50.0, 4.0, _quickSettingsProgress);

  double _getQuickSettingsBackgroundMaximizedWidth(SizeModel sizeModel) =>
      math.min(_kMaxQuickSettingsBackgroundWidth, sizeModel.screenSize.width) -
      2 * _kQuickSettingsHorizontalPadding;

  double _getQuickSettingsBackgroundWidth(SizeModel sizeModel) => lerpDouble(
      _userImageSize,
      _getQuickSettingsBackgroundMaximizedWidth(sizeModel),
      _quickSettingsProgress * (1.0 - _minimizationProgress));

  double _getQuickSettingsBackgroundHeight(SizeModel sizeModel) {
    return lerpDouble(
        _userImageSize,
        -_getUserImageTopOffset(sizeModel) +
            _userImageHeight +
            _userContextTextHeight +
            _importantInfoMaximizedHeight +
            _quickSettingsHeight,
        _quickSettingsProgress * (1.0 - _minimizationProgress));
  }

  double get _quickSettingsHeight =>
      _quickSettingsProgress * _quickSettingsMaximizedHeight;

  double get _fallAwayOpacity => (1.0 - _fallAwayProgress).clamp(0.0, 1.0);

  double get _slideInDistance => lerpDouble(10.0, 0.0, _slideInProgress);

  double get _quickSettingsRaiseDistance =>
      widget.quickSettingsHeightBump * _quickSettingsProgress;

  double _getScrollOffsetHeightDelta(double scrollOffset) =>
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
                          (1.0 - _minimizationProgress) *
                          (1.0 - _quickSettingsProgress)) *
              1000.0)
          .truncateToDouble() /
      1000.0;

  /// We fall away the context text and important information for the initial
  /// portion of the minimization animation as determined by
  /// [_kFallAwayDurationFraction].
  double get _fallAwayProgress =>
      math.min(1.0, (_minimizationProgress / _kFallAwayDurationFraction));

  /// We slide in the context text and important information for the final
  /// portion of the minimization animation as determined by
  /// [_kFallAwayDurationFraction].
  double get _slideInProgress =>
      ((((_minimizationProgress - (1.0 - _kFallAwayDurationFraction)) /
                  _kFallAwayDurationFraction)) *
              _minimizedInfoProgress)
          .clamp(0.0, 1.0);

  /// We slide up and fade in the quick settings for the final portion of the
  /// quick settings animation as determined by [_kFallAwayDurationFraction].
  double get _quickSettingsSlideUpProgress => math.max(
      0.0,
      ((_quickSettingsProgress - (1.0 - _kFallAwayDurationFraction)) /
          _kFallAwayDurationFraction));
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:sysui_widgets/three_column_aligned_layout_delegate.dart';

import 'nothing.dart';
import 'size_model.dart';
import 'story.dart';
import 'story_title.dart';

const RK4SpringDescription _kHeightSimulationDesc =
    const RK4SpringDescription(tension: 450.0, friction: 50.0);
const double _kPartMargin = 8.0;

const bool _kShowTitleOnly = true;

/// The bar to be shown at the top of a story.
class StoryBar extends StatefulWidget {
  /// The [Story] this bar represents.
  final Story story;

  /// True if the story should show its title only.
  final bool showTitleOnly;

  /// Elevation for the Physical Model that wraps the StoryBar
  final double elevation;

  /// BorderRadius for the Physical Model that wraps the StoryBar
  final BorderRadius borderRadius;

  /// Constructor.
  StoryBar({
    Key key,
    this.story,
    this.showTitleOnly: _kShowTitleOnly,
    this.elevation,
    this.borderRadius,
  })
      : super(key: key);

  @override
  _StoryBarState createState() => new _StoryBarState();
}

/// Holds the simulations for focus and height transitions.
class _StoryBarState extends State<StoryBar> {
  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<SizeModel>(
        builder: (
          _,
          Widget child,
          SizeModel sizeModel,
        ) =>
            sizeModel.storyBarHeightMinimized == 0.0 &&
                    sizeModel.storyBarHeightMaximized == 0.0
                ? Nothing.widget
                : new PhysicalModel(
                    color: widget.story.themeColor,
                    elevation: widget.elevation,
                    borderRadius: widget.borderRadius,
                    child: new ScopedModelDescendant<StoryBarHeightModel>(
                      builder: (
                        _,
                        Widget child,
                        StoryBarHeightModel storyBarHeightModel,
                      ) =>
                          new ScopedModelDescendant<StoryBarFocusModel>(
                            builder: (
                              _,
                              Widget child,
                              StoryBarFocusModel storyBarFocusModel,
                            ) =>
                                _buildStoryBar(
                                  storyBarHeightModel.value,
                                  storyBarFocusModel.value,
                                  sizeModel.storyBarHeightMinimized,
                                  sizeModel.storyBarHeightMaximized,
                                ),
                          ),
                    ),
                  ),
      );

  Widget _buildStoryBar(
    double heightValue,
    double focusValue,
    double storyBarHeightMinimized,
    double storyBarHeightMaximized,
  ) {
    double opacity = math
        .max(
            0.0,
            (heightValue - storyBarHeightMinimized) /
                (storyBarHeightMaximized - storyBarHeightMinimized))
        .clamp(0.0, 1.0);
    return new Container(
      color: widget.story.themeColor,
      height: heightValue - focusValue,
      padding: new EdgeInsets.symmetric(horizontal: 12.0),
      margin: new EdgeInsets.only(bottom: focusValue),
      child: new OverflowBox(
        minHeight: storyBarHeightMaximized,
        maxHeight: storyBarHeightMaximized,
        alignment: FractionalOffset.topCenter,
        child: widget.showTitleOnly
            ? new Center(
                child: new StoryTitle(
                  title: widget.story.title,
                  opacity: opacity,
                  baseColor: _textColor,
                ),
              )
            : new Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0.0,
                  vertical: 12.0,
                ),
                child: new CustomMultiChildLayout(
                  delegate: new ThreeColumnAlignedLayoutDelegate(
                    partMargin: _kPartMargin,
                  ),
                  children: <Widget>[
                    /// Module icons for the current story.
                    new LayoutId(
                      id: ThreeColumnAlignedLayoutDelegateParts.left,
                      child: new Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: widget.story.icons
                            .map(
                              (OpacityBuilder builder) => builder(
                                    context,
                                    opacity,
                                  ),
                            )
                            .toList(),
                      ),
                    ),

                    /// Story title.
                    new LayoutId(
                      id: ThreeColumnAlignedLayoutDelegateParts.center,
                      child: new StoryTitle(
                        title: widget.story.title,
                        opacity: opacity,
                        baseColor: _textColor,
                      ),
                    ),

                    /// For future use.
                    new LayoutId(
                      id: ThreeColumnAlignedLayoutDelegateParts.right,
                      child: Nothing.widget,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Color get _textColor {
    // See http://www.w3.org/TR/AERT#color-contrast for the details of this
    // algorithm.
    int brightness = (((widget.story.themeColor.red * 299) +
                (widget.story.themeColor.green * 587) +
                (widget.story.themeColor.blue * 114)) /
            1000)
        .round();

    return (brightness > 125) ? Colors.black : Colors.white;
  }
}

/// Handles the transition when the story bar minimizes and maximizes.
class StoryBarHeightModel extends SpringModel {
  bool _hidden = false;
  double _storyBarHeightMinimized;
  double _storyBarHeightMaximized;
  double _showHeight;

  /// Constructor.
  StoryBarHeightModel() : super(springDescription: _kHeightSimulationDesc);

  /// Called when the story bar heights change.
  void onStoryBarHeightsChanged(
    double storyBarHeightMinimized,
    double storyBarHeightMaximized,
  ) {
    if (_showHeight == null) {
      _showHeight = storyBarHeightMaximized;
      jump(_showHeight);
    }
    if (_showHeight == _storyBarHeightMinimized &&
        _storyBarHeightMinimized != storyBarHeightMinimized) {
      _showHeight = storyBarHeightMinimized;
    } else if (_showHeight == _storyBarHeightMaximized &&
        _storyBarHeightMaximized != storyBarHeightMaximized) {
      _showHeight = storyBarHeightMaximized;
    }
    if (!_hidden) {
      target = _showHeight;
    }
    _storyBarHeightMinimized = storyBarHeightMinimized;
    _storyBarHeightMaximized = storyBarHeightMaximized;
  }

  /// Shows the story bar.
  void show() {
    _hidden = false;
    target = _showHeight;
  }

  /// Hides the story bar.
  void hide() {
    _hidden = true;
    target = 0.0;
  }

  /// Maximizes the height of the story bar when shown.  If [jumpToFinish] is
  /// true the story bar height will jump to its maximized value instead of
  /// transitioning to it.
  void maximize({bool jumpToFinish: false}) {
    if (jumpToFinish) {
      jump(_storyBarHeightMaximized);
    }
    _showHeight = _storyBarHeightMaximized;
    show();
  }

  /// Minimizes the height of the story bar when shown.
  void minimize() {
    _showHeight = _storyBarHeightMinimized;
    show();
  }
}

const double _kStoryBarUnfocusedBottomGapHeight = 4.0;

/// Handles the transition when the story becomes focused.
class StoryBarFocusModel extends SpringModel {
  bool _focused = false;
  bool _minimized = true;

  /// Constructor.
  StoryBarFocusModel() : super(springDescription: _kHeightSimulationDesc);

  /// Maximizes the height of the story bar when shown.
  void maximize() {
    _minimized = false;
    target = _focused ? 0.0 : _kStoryBarUnfocusedBottomGapHeight;
  }

  /// Minimizes the height of the story bar when shown.
  void minimize() {
    _minimized = true;
    target = 0.0;
  }

  /// Sets the story bar into focus mode if true.
  set focus(bool focus) {
    if (_focused != focus) {
      _focused = focus;
      if (!_minimized) {
        target = _focused ? 0.0 : _kStoryBarUnfocusedBottomGapHeight;
      }
    }
  }
}

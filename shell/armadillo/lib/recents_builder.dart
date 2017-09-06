// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'armadillo_overlay.dart';
import 'now_builder.dart';
import 'scroll_locker.dart';
import 'size_model.dart';
import 'story_cluster.dart';
import 'story_drag_transition_model.dart';
import 'story_list.dart';
import 'vertical_shifter.dart';

/// Builds recents.
class RecentsBuilder {
  /// The [VerticalShifter] is used to shift the [StoryList] up when Now's
  /// inline quick settings are activated.
  final GlobalKey<VerticalShifterState> _verticalShifterKey =
      new GlobalKey<VerticalShifterState>();
  final GlobalKey<ScrollLockerState> _scrollLockerKey =
      new GlobalKey<ScrollLockerState>();
  final GlobalKey<ArmadilloOverlayState> _overlayKey =
      new GlobalKey<ArmadilloOverlayState>();

  /// Builds recents.
  Widget build(
    BuildContext context, {
    ScrollController scrollController,
    ValueChanged<double> onScroll,
    VoidCallback onStoryClusterFocusStarted,
    OnStoryClusterEvent onStoryClusterFocusCompleted,
    VoidCallback onStoryClusterVerticalEdgeHover,
  }) =>
      new ScopedModelDescendant<SizeModel>(
        builder: (
          BuildContext context,
          Widget child,
          SizeModel sizeModel,
        ) =>
            new ScopedModelDescendant<StoryDragTransitionModel>(
              builder: (
                BuildContext context,
                Widget child,
                StoryDragTransitionModel storyDragTransitionModel,
              ) =>
                  new Positioned(
                    left: 0.0,
                    right: 0.0,
                    top: 0.0,
                    bottom: lerpDouble(
                      sizeModel.minimizedNowHeight,
                      0.0,
                      storyDragTransitionModel.value,
                    ),
                    child: child,
                  ),
              child: new VerticalShifter(
                key: _verticalShifterKey,
                verticalShift: NowBuilder.kQuickSettingsHeightBump,
                child: new ScrollLocker(
                  key: _scrollLockerKey,
                  child: new StoryList(
                    scrollController: scrollController,
                    overlayKey: _overlayKey,
                    onScroll: onScroll,
                    onStoryClusterFocusStarted: onStoryClusterFocusStarted,
                    onStoryClusterFocusCompleted: onStoryClusterFocusCompleted,
                    onStoryClusterVerticalEdgeHover:
                        onStoryClusterVerticalEdgeHover,
                  ),
                ),
              ),
            ),
      );

  /// Call when a story cluster comes into focus.
  void onStoryFocused() {
    _scrollLockerKey.currentState.lock();
  }

  /// Call when a story cluster leaves focus.
  void onStoryUnfocused() {
    _scrollLockerKey.currentState.unlock();
  }

  /// Call when quick settings progress changes.
  void onQuickSettingsProgressChanged(double quickSettingsProgress) {
    _verticalShifterKey.currentState.shiftProgress = quickSettingsProgress;
  }
}

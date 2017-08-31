// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/widgets.dart';

import 'armadillo_overlay.dart';
import 'render_story_list_body.dart';
import 'simulation_builder.dart';
import 'size_model.dart';
import 'story.dart';
import 'story_cluster.dart';
import 'story_cluster_entrance_transition_model.dart';
import 'story_cluster_widget.dart';
import 'story_drag_transition_model.dart';
import 'story_list_body_parent_data.dart';
import 'story_list_layout.dart';
import 'story_model.dart';
import 'story_rearrangement_scrim_model.dart';

const double _kStoryInlineTitleHeight = 20.0;

const RK4SpringDescription _kInlinePreviewSimulationDesc =
    const RK4SpringDescription(tension: 900.0, friction: 50.0);

/// Displays the [StoryCluster]s of it's ancestor [StoryModel].
class StoryList extends StatelessWidget {
  /// Called when the story list scrolls.
  final ValueChanged<double> onScroll;

  /// Called when a story cluster begins to take focus.  This is when its
  /// focus animation begins.
  final VoidCallback onStoryClusterFocusStarted;

  /// Called when a story cluster has taken focus. This is when its
  /// focus animation finishes.
  final OnStoryClusterEvent onStoryClusterFocusCompleted;

  /// Controls the scrolling of this list.
  final ScrollController scrollController;

  /// The overlay dragged stories should place their avatars when dragging.
  final GlobalKey<ArmadilloOverlayState> overlayKey;

  /// Called when a cluster is dragged to the top or bottom of the screen for
  /// a certain length of time.
  final VoidCallback onStoryClusterVerticalEdgeHover;

  /// Constructor.
  StoryList({
    Key key,
    this.scrollController,
    this.overlayKey,
    this.onScroll,
    this.onStoryClusterFocusStarted,
    this.onStoryClusterFocusCompleted,
    this.onStoryClusterVerticalEdgeHover,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<StoryModel>(
        builder: (
          BuildContext context,
          Widget child,
          StoryModel storyModel,
        ) {
          return new ScopedModelDescendant<SizeModel>(
            builder: (
              BuildContext context,
              Widget child,
              SizeModel sizeModel,
            ) {
              return new Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  _createScrollableList(storyModel, sizeModel),
                  new ArmadilloOverlay(key: overlayKey),
                ],
              );
            },
          );
        },
      );

  Widget _createScrollableList(StoryModel storyModel, SizeModel sizeModel) =>
      new NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification &&
              notification.depth == 0) {
            onScroll?.call(notification.metrics.extentBefore);
          }
          return false;
        },
        child: new SingleChildScrollView(
          padding: new EdgeInsets.only(top: sizeModel.storyListTopPadding),
          reverse: true,
          controller: scrollController,
          child: new ScopedModelDescendant<SizeModel>(
            builder: (_, __, SizeModel sizeModel) =>
                new ScopedModelDescendant<StoryRearrangementScrimModel>(
                  builder: (
                    _,
                    __,
                    StoryRearrangementScrimModel storyRearrangementScrimModel,
                  ) =>
                      new ScopedModelDescendant<StoryDragTransitionModel>(
                        builder: (
                          BuildContext context,
                          _,
                          StoryDragTransitionModel storyDragTransitionModel,
                        ) =>
                            new AnimatedBuilder(
                              animation: scrollController,
                              builder: (BuildContext context, Widget child) =>
                                  new _StoryListBody(
                                    children: new List<Widget>.generate(
                                      storyModel.storyClusters.length,
                                      (int index) =>
                                          _createFocusableStoryCluster(
                                            context,
                                            storyModel.storyClusters,
                                            storyModel.storyClusters[index],
                                            storyModel.storyClusters[index]
                                                .buildStoryWidgets(
                                              context,
                                            ),
                                          ),
                                    ),
                                    listHeight: storyModel.listHeight,
                                    scrollOffset:
                                        scrollController?.offset ?? 0.0,
                                    bottomPadding: sizeModel.maximizedNowHeight,
                                    // When we are dragging, the storyListSize
                                    // takes up the entire screen since the now
                                    // bar is hidden.
                                    parentSize: new Size(
                                      sizeModel.storySize.width,
                                      sizeModel.storySize.height +
                                          lerpDouble(
                                            0.0,
                                            sizeModel.minimizedNowHeight,
                                            storyDragTransitionModel.progress,
                                          ),
                                    ),
                                    storyDragTransitionModelProgress:
                                        storyDragTransitionModel.progress,
                                  ),
                            ),
                      ),
                ),
          ),
        ),
      );

  Widget _createFocusableStoryCluster(
    BuildContext context,
    List<StoryCluster> storyClusters,
    StoryCluster storyCluster,
    Map<StoryId, Widget> storyWidgets,
  ) =>
      new ScopedModel<StoryClusterEntranceTransitionModel>(
        model: storyCluster.storyClusterEntranceTransitionModel,
        child: new ScopedModelDescendant<StoryClusterEntranceTransitionModel>(
          builder: (
            _,
            __,
            StoryClusterEntranceTransitionModel
                storyClusterEntranceTransitionModel,
          ) =>
              new SimulationBuilder(
                key: storyCluster.inlinePreviewHintScaleSimulationKey,
                springDescription: _kInlinePreviewSimulationDesc,
                initValue: 0.0,
                targetValue: 0.0,
                builder: (
                  BuildContext context,
                  double inlinePreviewHintScaleProgress,
                ) =>
                    new SimulationBuilder(
                      key: storyCluster.inlinePreviewScaleSimulationKey,
                      springDescription: _kInlinePreviewSimulationDesc,
                      initValue: 0.0,
                      targetValue: 0.0,
                      builder: (BuildContext context,
                              double inlinePreviewScaleProgress) =>
                          new SimulationBuilder(
                            key: storyCluster.focusSimulationKey,
                            initValue: 0.0,
                            targetValue: 0.0,
                            onSimulationChanged:
                                (double focusProgress, bool isDone) {
                              if (focusProgress == 1.0 && isDone) {
                                onStoryClusterFocusCompleted
                                    ?.call(storyCluster);
                              }
                            },
                            builder:
                                (BuildContext context, double focusProgress) =>
                                    new _StoryListChild(
                                      storyLayout: storyCluster.storyLayout,
                                      focusProgress: focusProgress,
                                      inlinePreviewScaleProgress:
                                          inlinePreviewScaleProgress,
                                      inlinePreviewHintScaleProgress:
                                          inlinePreviewHintScaleProgress,
                                      entranceTransitionProgress:
                                          storyClusterEntranceTransitionModel
                                              .progress,
                                      child: _createStoryCluster(
                                        storyClusters,
                                        storyCluster,
                                        focusProgress,
                                        storyWidgets,
                                      ),
                                    ),
                          ),
                    ),
              ),
        ),
      );

  Widget _createStoryCluster(
    List<StoryCluster> storyClusters,
    StoryCluster storyCluster,
    double progress,
    Map<StoryId, Widget> storyWidgets,
  ) =>
      new RepaintBoundary(
        child: new StoryClusterWidget(
          overlayKey: overlayKey,
          focusProgress: progress,
          storyCluster: storyCluster,
          onAccept: () {
            if (!_inFocus(storyCluster)) {
              _onGainFocus(storyClusters, storyCluster);
            }
          },
          onTap: () => _onGainFocus(storyClusters, storyCluster),
          onVerticalEdgeHover: onStoryClusterVerticalEdgeHover,
          storyWidgets: storyWidgets,
        ),
      );

  bool _inFocus(StoryCluster s) =>
      (s.focusSimulationKey.currentState?.progress ?? 0.0) > 0.0;

  void _onGainFocus(
    List<StoryCluster> storyClusters,
    StoryCluster storyCluster,
  ) {
    // Defocus any focused stories.
    storyClusters.forEach((StoryCluster s) {
      if (_inFocus(s)) {
        s.unFocus();
      }
    });

    // Bring tapped story into focus.
    storyCluster.focusSimulationKey.currentState?.target = 1.0;

    storyCluster.maximizeStoryBars();

    onStoryClusterFocusStarted?.call();
  }
}

class _StoryListBody extends MultiChildRenderObjectWidget {
  final double _scrollOffset;
  final double _bottomPadding;
  final double _listHeight;
  final Size _parentSize;
  final double _storyDragTransitionModelProgress;

  /// Constructor.
  _StoryListBody({
    Key key,
    List<Widget> children,
    double scrollOffset,
    double bottomPadding,
    double listHeight,
    Size parentSize,
    double storyDragTransitionModelProgress,
  })
      : _scrollOffset = scrollOffset,
        _bottomPadding = bottomPadding,
        _listHeight = listHeight,
        _parentSize = parentSize,
        _storyDragTransitionModelProgress = storyDragTransitionModelProgress,
        super(key: key, children: children);

  @override
  RenderStoryListBody createRenderObject(BuildContext context) =>
      new RenderStoryListBody(
        parentSize: _parentSize,
        scrollOffset: _scrollOffset,
        bottomPadding: _bottomPadding,
        listHeight: _listHeight,
        liftScale: lerpDouble(
          1.0,
          0.9,
          _storyDragTransitionModelProgress,
        ),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderStoryListBody renderObject,
  ) {
    renderObject
      ..mainAxis = Axis.vertical
      ..parentSize = _parentSize
      ..scrollOffset = _scrollOffset
      ..bottomPadding = _bottomPadding
      ..listHeight = _listHeight
      ..liftScale = lerpDouble(
        1.0,
        0.9,
        _storyDragTransitionModelProgress,
      );
  }
}

class _StoryListChild extends ParentDataWidget<_StoryListBody> {
  final StoryLayout _storyLayout;
  final double _focusProgress;
  final double _inlinePreviewScaleProgress;
  final double _inlinePreviewHintScaleProgress;
  final double _entranceTransitionProgress;

  _StoryListChild({
    Widget child,
    StoryLayout storyLayout,
    double focusProgress,
    double inlinePreviewScaleProgress,
    double inlinePreviewHintScaleProgress,
    double entranceTransitionProgress,
  })
      : _storyLayout = storyLayout,
        _focusProgress = focusProgress,
        _inlinePreviewScaleProgress = inlinePreviewScaleProgress,
        _inlinePreviewHintScaleProgress = inlinePreviewHintScaleProgress,
        _entranceTransitionProgress = entranceTransitionProgress,
        super(child: child);

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is StoryListBodyParentData);
    final StoryListBodyParentData parentData = renderObject.parentData;
    parentData
      ..storyLayout = _storyLayout
      ..focusProgress = _focusProgress
      ..inlinePreviewScaleProgress = _inlinePreviewScaleProgress
      ..inlinePreviewHintScaleProgress = _inlinePreviewHintScaleProgress
      ..entranceTransitionProgress = _entranceTransitionProgress;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(
      new DiagnosticsProperty<StoryLayout>(
        'storyLayout',
        _storyLayout,
      ),
    );
    description.add(
      new DoubleProperty(
        'focusProgress',
        _focusProgress,
      ),
    );
    description.add(
      new DoubleProperty(
        'inlinePreviewScaleProgress',
        _inlinePreviewScaleProgress,
      ),
    );
    description.add(
      new DoubleProperty(
        'inlinePreviewHintScaleProgress',
        _inlinePreviewHintScaleProgress,
      ),
    );
    description.add(
      new DoubleProperty(
        'entranceTransitionProgress',
        _entranceTransitionProgress,
      ),
    );
  }
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'armadillo_drag_target.dart';
import 'armadillo_overlay.dart';
import 'render_story_list_body.dart';
import 'size_model.dart';
import 'story.dart';
import 'story_cluster.dart';
import 'story_cluster_drag_data.dart';
import 'story_cluster_entrance_transition_model.dart';
import 'story_cluster_widget.dart';
import 'story_drag_transition_model.dart';
import 'story_list_body_parent_data.dart';
import 'story_list_layout.dart';
import 'story_model.dart';
import 'story_rearrangement_scrim_model.dart';

const double _kStoryInlineTitleHeight = 20.0;

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
  const StoryList({
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
                  new Positioned(
                    left: 0.0,
                    top: 0.0,
                    bottom: 0.0,
                    width: 108.0,
                    child: _buildDiscardDragTarget(
                      storyModel: storyModel,
                      controller: new AnimationController(
                        vsync: new _TickerProvider(),
                        duration: const Duration(milliseconds: 200),
                      ),
                    ),
                  ),
                  new Positioned(
                    right: 0.0,
                    top: 0.0,
                    bottom: 0.0,
                    width: 108.0,
                    child: _buildDiscardDragTarget(
                      storyModel: storyModel,
                      controller: new AnimationController(
                        vsync: new _TickerProvider(),
                        duration: const Duration(milliseconds: 200),
                      ),
                    ),
                  ),
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
                                            storyDragTransitionModel.value,
                                          ),
                                    ),
                                    storyDragTransitionModelProgress:
                                        storyDragTransitionModel.value,
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
  ) {
    bool wasFocused = (storyCluster.focusModel.value == 1.0 &&
        storyCluster.focusModel.isDone);
    return _wrapWithModels(storyCluster, (BuildContext context) {
      bool isFocused = (storyCluster.focusModel.value == 1.0 &&
          storyCluster.focusModel.isDone);
      if (isFocused && !wasFocused) {
        /// TODO: Investigate if this gets called too much.
        scheduleMicrotask(
            () => onStoryClusterFocusCompleted?.call(storyCluster));
      }
      wasFocused = isFocused;
      return new _StoryListChild(
        storyLayout: storyCluster.storyLayout,
        focusProgress: storyCluster.focusModel.value,
        inlinePreviewScaleProgress: storyCluster.inlinePreviewScaleModel.value,
        inlinePreviewHintScaleProgress:
            storyCluster.inlinePreviewHintScaleModel.value,
        entranceTransitionProgress:
            storyCluster.storyClusterEntranceTransitionModel.value,
        child: _createStoryCluster(
          storyClusters,
          storyCluster,
          storyCluster.focusModel.value,
          storyWidgets,
        ),
      );
    });
  }

  Widget _wrapWithModels(StoryCluster storyCluster, WidgetBuilder builder) =>
      new ScopedModel<StoryClusterEntranceTransitionModel>(
        model: storyCluster.storyClusterEntranceTransitionModel,
        child: new ScopedModelDescendant<StoryClusterEntranceTransitionModel>(
          builder: (_, __, ___) => new ScopedModel<InlinePreviewScaleModel>(
                model: storyCluster.inlinePreviewScaleModel,
                child: new ScopedModelDescendant<InlinePreviewScaleModel>(
                  builder: (_, __, ___) =>
                      new ScopedModel<InlinePreviewHintScaleModel>(
                        model: storyCluster.inlinePreviewHintScaleModel,
                        child: new ScopedModelDescendant<
                            InlinePreviewHintScaleModel>(
                          builder: (_, __, ___) => new ScopedModel<FocusModel>(
                                model: storyCluster.focusModel,
                                child: new ScopedModelDescendant<FocusModel>(
                                  builder: (BuildContext context, __, ___) =>
                                      builder(context),
                                ),
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

  bool _inFocus(StoryCluster s) => s.focusModel.value > 0.0;

  void _onGainFocus(
    List<StoryCluster> storyClusters,
    StoryCluster storyCluster,
  ) {
    // Defocus any focused stories.
    for (StoryCluster s in storyClusters) {
      if (_inFocus(s)) {
        s.unFocus();
      }
    }

    // Bring tapped story into focus.
    storyCluster.focusModel.target = 1.0;

    storyCluster.maximizeStoryBars();

    onStoryClusterFocusStarted?.call();
  }

  Widget _buildDiscardDragTarget({
    BuildContext context,
    StoryModel storyModel,
    AnimationController controller,
  }) {
    CurvedAnimation curve = new CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    bool wasEmpty = true;
    return new ArmadilloDragTarget<StoryClusterDragData>(
      onWillAccept: (_, __) => storyModel.storyClusters.every(
          (StoryCluster storyCluster) => storyCluster.focusModel.value == 0.0),
      onAccept: (StoryClusterDragData data, _, __) {
        storyModel.delete(storyModel.getStoryCluster(data.id));
        controller.reverse();
      },
      builder: (_, Map<StoryClusterDragData, Offset> candidateData, __) {
        if (candidateData.isEmpty && !wasEmpty) {
          controller.reverse();
        } else if (candidateData.isNotEmpty && wasEmpty) {
          controller.forward();
        }
        wasEmpty = candidateData.isEmpty;

        return new IgnorePointer(
          child: new AnimatedBuilder(
            animation: curve,
            builder: (BuildContext context, Widget child) => new Container(
                  color: Color.lerp(
                    Colors.transparent,
                    Colors.black12,
                    curve.value,
                  ),
                ),
          ),
        );
      },
    );
  }
}

class _TickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);
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

  const _StoryListChild({
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
    _setParentData(renderObject.parentData);
  }

  void _setParentData(StoryListBodyParentData parentData) {
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
    description
      ..add(
        new DiagnosticsProperty<StoryLayout>(
          'storyLayout',
          _storyLayout,
        ),
      )
      ..add(
        new DoubleProperty(
          'focusProgress',
          _focusProgress,
        ),
      )
      ..add(
        new DoubleProperty(
          'inlinePreviewScaleProgress',
          _inlinePreviewScaleProgress,
        ),
      )
      ..add(
        new DoubleProperty(
          'inlinePreviewHintScaleProgress',
          _inlinePreviewHintScaleProgress,
        ),
      )
      ..add(
        new DoubleProperty(
          'entranceTransitionProgress',
          _entranceTransitionProgress,
        ),
      );
  }
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'conductor_model.dart';
import 'context_model.dart';
import 'peek_model.dart';
import 'size_model.dart';
import 'story.dart';
import 'story_cluster.dart';
import 'story_model.dart';
import 'suggestion_model.dart';

/// Manages the position, size, and state of the story list, user context,
/// suggestion overlay, device extensions. interruption overlay, and quick
/// settings overlay.
class Conductor extends StatefulWidget {
  /// Constructor.
  Conductor({Key key}) : super(key: key);

  @override
  ConductorState createState() => new ConductorState();
}

/// Manages the state for [Conductor].
class ConductorState extends State<Conductor> {
  bool _ignoreNextScrollOffsetChange = false;
  double _pointerDownY;

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<ConductorModel>(
        builder: (_, __, ConductorModel conductorModel) =>
            new ScopedModelDescendant<SizeModel>(
              builder: (_, __, SizeModel sizeModel) {
                double idleModeOffset = sizeModel.screenSize.width * 1.5;
                return new ScopedModelDescendant<IdleModel>(
                  builder: (
                    BuildContext context,
                    Widget child,
                    IdleModel idleModel,
                  ) =>
                      new Transform(
                        transform: new Matrix4.translationValues(
                          lerpDouble(
                            0.0,
                            idleModeOffset,
                            idleModel.value,
                          ),
                          0.0,
                          0.0,
                        ),
                        child: new Stack(
                          overflow: Overflow.visible,
                          children: <Widget>[
                            new Positioned.fill(
                              child: new Offstage(
                                offstage: idleModel.value == 1.0,
                                child: child,
                              ),
                            ),
                            new Positioned(
                              top: 0.0,
                              left: -idleModeOffset,
                              width: sizeModel.screenSize.width,
                              height: sizeModel.screenSize.height,
                              child: new Offstage(
                                offstage: idleModel.value == 0.0,
                                child: conductorModel.idleModeBuilder.build(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  child: _buildParts(context, conductorModel),
                );
              },
            ),
      );

  /// Note in particular the magic we're employing here to make the user
  /// state appear to be a part of the story list:
  /// By giving the story list bottom padding and clipping its bottom to the
  /// size of the final user state bar we have the user state appear to be
  /// a part of the story list and yet prevent the story list from painting
  /// behind it.
  Widget _buildParts(
    BuildContext context,
    ConductorModel conductorModel,
  ) =>
      new Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          /// Story List.
          conductorModel.recentsBuilder.build(
            context,
            onScroll: (double scrollOffset) {
              // Ignore top padding of storylist when looking at scroll offset
              // to determine Now state.
              conductorModel.nowBuilder.onRecentsScrollOffsetChanged(
                scrollOffset + SizeModel.of(context).storyListTopPadding,
                _ignoreNextScrollOffsetChange,
              );

              if (_ignoreNextScrollOffsetChange) {
                _ignoreNextScrollOffsetChange = false;
                return;
              }
              conductorModel.nextBuilder.onRecentsScrollOffsetChanged(
                context,
                scrollOffset,
              );
            },
            onStoryClusterFocusStarted: () {
              // Lock scrolling.
              conductorModel.recentsBuilder.onStoryFocused();
              _minimizeNow();
            },
            onStoryClusterFocusCompleted: (StoryCluster storyCluster) {
              _focusStoryCluster(storyCluster);
            },
            onStoryClusterVerticalEdgeHover: () => goToOrigin(),
          ),

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
              if (conductorModel.recentsBuilder.isSignificantlyOverscrolled(
                  _pointerDownY - event.position.dy)) {
                conductorModel.nextBuilder.show();
              }
              conductorModel.nowBuilder.onHideQuickSettings();
            },
          ),
          // Now.
          conductorModel.nowBuilder.build(
            context,
            onQuickSettingsProgressChange: (double quickSettingsProgress) =>
                conductorModel.recentsBuilder
                    .onQuickSettingsProgressChanged(quickSettingsProgress),
            onMinimizedTap: () => goToOrigin(),
            onQuickSettingsMaximized: () {
              ConductorModel.of(context).recentsBuilder.resetScroll();
            },
            onMinimize: () {
              PeekModel.of(context).nowMinimized = true;
              conductorModel.nextBuilder.hide();
            },
            onMaximize: () {
              PeekModel.of(context).nowMinimized = false;
              conductorModel.nextBuilder.hide();
            },
            onBarVerticalDragUpdate: (DragUpdateDetails details) =>
                conductorModel.nextBuilder.onNowBarVerticalDragUpdate(details),
            onBarVerticalDragEnd: (DragEndDetails details) =>
                conductorModel.nextBuilder.onNowBarVerticalDragEnd(details),
            onMinimizedContextTapped: () => conductorModel.nextBuilder.show(),
          ),

          // Suggestions Overlay.
          conductorModel.nextBuilder.build(
            context,
            onMinimizeNow: _minimizeNow,
          ),
        ],
      );

  void _defocus(StoryModel storyModel) {
    // Unfocus all story clusters.
    storyModel.storyClusters.forEach(
      (StoryCluster storyCluster) => storyCluster.unFocus(),
    );

    // Unlock scrolling.
    ConductorModel.of(context).recentsBuilder.onStoryUnfocused();
    ConductorModel.of(context).recentsBuilder.resetScroll();
  }

  void _focusStoryCluster(
    StoryCluster storyCluster,
  ) {
    StoryModel storyModel = StoryModel.of(context);

    // Tell the [StoryModel] the story is now in focus.  This will move the
    // [Story] to the front of the [StoryList].
    storyModel.interactionStarted(storyCluster);

    // We need to set the scroll offset to 0.0 to ensure the story
    // bars don't become untouchable when fully focused:
    // If we're at a scroll offset other than zero, the RenderStoryListBody
    // might not be as big as it would need to be to fully cover the screen and
    // thus would have areas where its painting but not receiving hit testing.
    // Right now the RenderStoryListBody ensures that its at least the size of
    // the screen when we're focused but doesn't take into account the scroll
    // offset.  It seems weird to size the RenderStoryListBody based on the
    // scroll offset and it also seems weird to scroll to offset 0.0 from some
    // arbitrary scroll offset when we defocus so this solves both issues with
    // one stone.
    //
    // If we don't ignore the onScroll resulting from setting the scroll offset
    // to 0.0 we will inadvertently maximize now and peek the suggestion
    // overlay.
    _ignoreNextScrollOffsetChange = true;
    ConductorModel.of(context).recentsBuilder.resetScroll(jump: true);
    ConductorModel.of(context).recentsBuilder.onStoryFocused();
  }

  void _minimizeNow() {
    ConductorModel.of(context).nowBuilder.onMinimize();
    PeekModel.of(context).nowMinimized = true;
    ConductorModel.of(context).nextBuilder.hide();
  }

  /// Returns the state of the children to their initial values.
  /// This includes:
  /// 1) Unfocusing any focused stories.
  /// 2) Maximizing now.
  /// 3) Enabling scrolling of the story list.
  /// 4) Scrolling to the beginning of the story list.
  /// 5) Peeking the suggestion list.
  void goToOrigin() {
    StoryModel storyModel = StoryModel.of(context);
    _defocus(storyModel);
    ConductorModel.of(context).nowBuilder.onMaximize();
    storyModel.interactionStopped();
    storyModel.clearPlaceHolderStoryClusters();
  }

  /// Called to request the conductor focus on the cluster with [storyId].
  void requestStoryFocus(StoryId storyId, {bool jumpToFinish: true}) {
    ConductorModel.of(context).recentsBuilder.onStoryFocused();
    _minimizeNow();
    _focusOnStory(storyId, jumpToFinish: jumpToFinish);
  }

  void _focusOnStory(StoryId storyId, {bool jumpToFinish: true}) {
    StoryModel storyModel = StoryModel.of(context);
    List<StoryCluster> targetStoryClusters =
        storyModel.storyClusters.where((StoryCluster storyCluster) {
      bool result = false;
      storyCluster.stories.forEach((Story story) {
        if (story.id == storyId) {
          result = true;
        }
      });
      return result;
    }).toList();

    // There should be only one story cluster with a story with this id.  If
    // that's not true, bail out.
    if (targetStoryClusters.length != 1) {
      print(
        'WARNING: Found ${targetStoryClusters.length} story clusters with '
            'a story with id $storyId. Returning to origin.',
      );
      goToOrigin();
    } else {
      // Unfocus all story clusters.
      storyModel.storyClusters.forEach(
        (StoryCluster storyCluster) => storyCluster.unFocus(),
      );

      // Ensure the focused story is completely expanded.
      targetStoryClusters[0].focusModel.jump(1.0);
      targetStoryClusters[0].storyClusterEntranceTransitionModel.jump(1.0);

      // Ensure the focused story's story bar is full open.
      targetStoryClusters[0].maximizeStoryBars(jumpToFinish: jumpToFinish);

      // Focus on the story cluster.
      _focusStoryCluster(targetStoryClusters[0]);
    }

    ConductorModel.of(context).nextBuilder.resetSelection();
  }
}

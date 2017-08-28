// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'display_mode.dart';
import 'panel.dart';
import 'story.dart';
import 'story_cluster.dart';
import 'story_cluster_id.dart';
import 'story_list_layout.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

/// A simple story model that gets its stories from calls
/// [onStoryClustersChanged] and  reorders them with user interaction.
class StoryModel extends Model {
  /// Called when the currently focused [StoryCluster] changes.
  final OnStoryClusterEvent onFocusChanged;
  List<StoryCluster> _storyClusters = <StoryCluster>[];
  Size _lastLayoutSize = Size.zero;
  double _listHeight = 0.0;

  /// Constructor.
  StoryModel({this.onFocusChanged});

  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static StoryModel of(BuildContext context, {bool rebuildOnChange: false}) =>
      new ModelFinder<StoryModel>()
          .of(context, rebuildOnChange: rebuildOnChange);

  /// Returns the current list of [StoryCluster]s.
  List<StoryCluster> get storyClusters => _storyClusters;

  /// The current height of the story list.
  double get listHeight => _listHeight;

  /// Called to set a new list of [storyClusters].
  void onStoryClustersChanged(List<StoryCluster> storyClusters) {
    _storyClusters = storyClusters;
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Update indicies
    for (int i = 0; i < _storyClusters.length; i++) {
      StoryCluster storyCluster = _storyClusters[i];
      storyCluster.stories.forEach(
        (Story story) {
          story.clusterIndex = i;
        },
      );
    }

    super.notifyListeners();
  }

  /// Updates the [size] used to layout the stories.
  void updateLayouts(Size size) {
    if (size.width == 0.0 || size.height == 0.0) {
      return;
    }
    _lastLayoutSize = size;

    // Sort recently interacted with stories to the start of the list.
    _storyClusters.sort((StoryCluster a, StoryCluster b) =>
        b.lastInteraction.millisecondsSinceEpoch -
        a.lastInteraction.millisecondsSinceEpoch);

    List<StoryLayout> storyLayout = new StoryListLayout(size: size).layout(
      storyClustersToLayout: _storyClusters,
      currentTime: new DateTime.now(),
    );

    double listHeight = 0.0;
    for (int i = 0; i < storyLayout.length; i++) {
      _storyClusters[i].storyLayout = storyLayout[i];
      listHeight = math.max(listHeight, -storyLayout[i].offset.dy);
    }
    _listHeight = listHeight;

    /// We delay each story a bit more so we have a staggered entrance
    /// transition.  We also delay all stories by a set amount dependent on the
    /// number of clusters that haven't loaded in yet.  This should reduce jank
    /// while those clusters load for the first time.
    int unenteredClusters = _storyClusters
        .where(
          (StoryCluster storyCluster) =>
              storyCluster.storyClusterEntranceTransitionModel.progress == 0.0,
        )
        .length;

    int delayMultiple = 0;
    _storyClusters.forEach((StoryCluster storyCluster) {
      if (storyCluster.storyClusterEntranceTransitionModel.progress == 0.0) {
        storyCluster.storyClusterEntranceTransitionModel.reset(
          delay:
              (0.5 * math.min(6, unenteredClusters)) + (0.25 * delayMultiple),
          completed: false,
        );
        delayMultiple++;
      }
    });
  }

  /// Updates the [Story.lastInteraction] of [storyCluster] to be [DateTime.now].
  /// This method is to be called whenever a [Story]'s [Story.builder] [Widget]
  /// comes into focus.
  void interactionStarted(StoryCluster storyCluster) {
    storyCluster.lastInteraction = new DateTime.now();
    updateLayouts(_lastLayoutSize);
    notifyListeners();
    onFocusChanged?.call(storyCluster);
  }

  /// Indicates the currently focused story cluster has been defocused.
  void interactionStopped() {
    notifyListeners();
    onFocusChanged?.call(null);
  }

  /// Randomizes story interaction times within the story cluster.
  void randomizeStoryTimes() {
    math.Random random = new math.Random();
    DateTime storyInteractionTime = new DateTime.now();
    _storyClusters.forEach((StoryCluster storyCluster) {
      storyInteractionTime = storyInteractionTime.subtract(
          new Duration(minutes: math.max(0, random.nextInt(100) - 70)));
      Duration interaction = new Duration(minutes: random.nextInt(60));
      storyCluster.lastInteraction = storyInteractionTime;
      storyCluster.cumulativeInteractionDuration = interaction;
      storyInteractionTime = storyInteractionTime.subtract(interaction);
    });
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  /// Adds [source]'s stories to [target]'s stories and removes [source] from
  /// the list of story clusters.
  void combine({StoryCluster source, StoryCluster target}) {
    // Update grid locations.
    for (int i = 0; i < source.stories.length; i++) {
      Story sourceStory = source.stories[i];
      Story largestStory = _getLargestStory(target.stories);
      largestStory.panel.split((Panel a, Panel b) {
        target.replace(panel: largestStory.panel, withPanel: a);
        target.add(story: sourceStory, withPanel: b);
        target.normalizeSizes();
      });
      if (!largestStory.panel.canBeSplitVertically(_lastLayoutSize.width) &&
          !largestStory.panel.canBeSplitHorizontally(_lastLayoutSize.height)) {
        target.displayMode = DisplayMode.tabs;
      }
    }

    // We need to update the draggable id as in some cases this id could
    // be used by one of the cluster's stories.
    source.becomePlaceholder();
    target.clusterDraggableKey = new GlobalKey();
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  /// Removes [storyCluster] from the list of story clusters.
  void remove(StoryCluster storyCluster) {
    storyCluster.becomePlaceholder();
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  /// Removes [storyToSplit] from [from]'s stories and updates [from]'s stories
  /// panels.  [storyToSplit] becomes forms its own [StoryCluster] which is
  /// added to the story cluster list.
  void split({Story storyToSplit, StoryCluster from}) {
    assert(from.stories.contains(storyToSplit));

    from.absorb(storyToSplit);

    clearPlaceHolderStoryClusters();
    _storyClusters.add(
      new StoryCluster.fromStory(
        storyToSplit,
        from.onStoryClusterChanged,
      ),
    );
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  /// Determines the max number of rows and columns based on [size] and either
  /// does nothing, rearrange the panels to fit, or switches to tabs.
  void normalize({Size size}) {
    // TODO(apwilson): implement this!
  }

  /// Finds and returns the [StoryCluster] with the id equal to
  /// [storyClusterId].
  /// TODO(apwilson): have callers handle when the story cluster no longer exists.
  StoryCluster getStoryCluster(StoryClusterId storyClusterId) => _storyClusters
      .where((StoryCluster storyCluster) => storyCluster.id == storyClusterId)
      .single;

  /// Removes any [StoryCluster]s that consist of entirely place holder stories.
  void clearPlaceHolderStoryClusters() {
    _storyClusters.removeWhere(
      (StoryCluster storyCluster) => storyCluster.realStories.isEmpty,
    );
    updateLayouts(_lastLayoutSize);
    notifyListeners();
  }

  Story _getLargestStory(List<Story> stories) {
    double largestSize = -0.0;
    Story largestStory;
    stories.forEach((Story story) {
      double storySize = story.panel.sizeFactor;
      if (storySize > largestSize) {
        largestSize = storySize;
        largestStory = story;
      }
    });
    return largestStory;
  }
}

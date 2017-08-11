// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.story/story_controller.fidl.dart';
import 'package:apps.modular.services.story/story_info.fidl.dart';
import 'package:apps.modular.services.story/story_state.fidl.dart';
import 'package:apps.modular.services.story/story_provider.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:armadillo/story.dart';
import 'package:armadillo/story_cluster.dart';
import 'package:armadillo/story_cluster_id.dart';
import 'package:armadillo/story_generator.dart';
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart' as bindings;
import 'package:lib.logging/logging.dart';

import 'hit_test_model.dart';
import 'story_importance_watcher_impl.dart';
import 'story_provider_watcher_impl.dart';

const int _kMaxActiveClusters = 6;

/// Creates a list of stories for the StoryList using
/// modular's [StoryProvider].
class StoryProviderStoryGenerator extends StoryGenerator {
  final Set<VoidCallback> _listeners = new Set<VoidCallback>();
  bool _firstTime = true;
  bool _writeStoryClusterUpdatesToLink = false;
  bool _reactToLinkUpdates = false;
  bool _dragging = false;
  String _lastLinkJson;
  String _lastProcessedLinkJson;

  /// Set from an external source - typically the UserShell.
  StoryProviderProxy _storyProvider;

  /// Set from an external source - typically the UserShell.
  Link _link;

  final List<StoryCluster> _storyClusters = <StoryCluster>[];

  final Map<String, StoryControllerProxy> _storyControllerMap =
      <String, StoryControllerProxy>{};

  final StoryProviderWatcherBinding _storyProviderWatcherBinding =
      new StoryProviderWatcherBinding();

  final StoryImportanceWatcherBinding _storyImportanceWatcherBinding =
      new StoryImportanceWatcherBinding();

  /// Called the first time the [StoryProvider] returns stories.
  final VoidCallback onStoriesFirstAvailable;

  /// Constructor.
  StoryProviderStoryGenerator({this.onStoriesFirstAvailable});

  /// Call to close all the handles opened by this story generator.
  void close() {
    _storyProviderWatcherBinding.close();
    _storyImportanceWatcherBinding.close();
    _storyControllerMap.values.forEach(
      (StoryControllerProxy storyControllerProxy) =>
          storyControllerProxy.ctrl.close(),
    );
  }

  /// Sets the [StoryProvider] used to get and start stories.
  set storyProvider(StoryProviderProxy storyProvider) {
    _storyProvider = storyProvider;
    _storyProvider.watch(
      _storyProviderWatcherBinding.wrap(
        new StoryProviderWatcherImpl(
          onStoryChanged: _onStoryChanged,
          onStoryDeleted: (String storyId) => _removeStory(storyId),
        ),
      ),
    );

    _storyProvider.watchImportance(
      _storyImportanceWatcherBinding.wrap(
        new StoryImportanceWatcherImpl(
          onImportanceChanged: () {
            _storyProvider.getImportance((Map<String, double> importance) {
              _currentStories.forEach((Story story) {
                story.importance = importance[story.id.value] ?? 1.0;
              });
              _notifyListeners();
            });
          },
        ),
      ),
    );
    update();
  }

  /// Sets the [Link] used to set clustering information.
  set link(Link link) {
    _link = link;
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  List<StoryCluster> get storyClusters => _storyClusters;

  /// Called when the drag state of a cluster changes.
  void onDraggingChanged(bool dragging) {
    if (dragging != _dragging) {
      _dragging = dragging;
      _onLinkUpdate();
    }
  }

  /// Called when the link changes.
  void onLinkChanged(String json) {
    if (json == _lastLinkJson) {
      return;
    }

    log.fine('Link changed: $json');

    _lastLinkJson = json;

    _onLinkUpdate();
  }

  void _onLinkUpdate() {
    if (!_reactToLinkUpdates) {
      return;
    }

    if (_dragging) {
      return;
    }

    if (_lastProcessedLinkJson == _lastLinkJson) {
      return;
    }

    log.fine('Processing link data...');

    List<StoryCluster> jsonStoryClusters = _getStoryClustersFromJson(
      _lastLinkJson,
    );

    log.fine(
      'Current cluster count: ${storyClusters.length}, '
          'decoded cluster count: ${jsonStoryClusters.length}',
    );

    /// If the list of stories doesn't match the canonical list of stories, do nothing.
    Iterable<Story> jsonStories = jsonStoryClusters.expand(
      (StoryCluster cluster) => cluster.stories,
    );

    Map<String, Story> currentStoriesMap = <String, Story>{};

    _currentStories.forEach(
      (Story story) => currentStoriesMap[story.id.value] = story,
    );

    /// Only continue processing if we have the same set of stories.
    if (jsonStories.length != currentStoriesMap.length) {
      log.fine('Not the same number of stories! Aborting JSON processing...');
      return;
    }

    if (!jsonStories.every(
      (Story jsonStory) => currentStoriesMap.containsKey(jsonStory.id.value),
    )) {
      log.fine('Not all stories exist! Aborting JSON processing...');
      return;
    }

    _lastProcessedLinkJson = _lastLinkJson;

    /// At this point the stories match, now we need move from the current
    /// clustering arrangement to the one specified in the json.
    /// Replace the current list of clusters with this list by merging the
    /// clusters.
    log.fine(
      'Processing new Story Clusters from Link:\n$_lastProcessedLinkJson',
    );

    /// Currently, each StoryCluster created from the json has incomplete
    /// stories.  Before messing with the clusters we replace these incomplete
    /// stories with currently existing ones with some of their data updated
    /// from the incomplete json stories.
    jsonStoryClusters.forEach((StoryCluster jsonStoryCluster) {
      List<Story> jsonStoryClusterStories = jsonStoryCluster.stories;
      List<Story> replacementStories = <Story>[];
      jsonStoryClusterStories.forEach((Story jsonStory) {
        Story replacementStory = currentStoriesMap[jsonStory.id.value];
        replacementStory.update(jsonStory);
        replacementStories.add(replacementStory);
      });
      jsonStoryCluster.replaceStories(replacementStories);
    });

    List<StoryCluster> oldStoryClusters = _storyClusters.toList();
    List<StoryCluster> newStoryClusters = <StoryCluster>[];

    /// For each json story cluster...
    jsonStoryClusters.forEach((StoryCluster jsonStoryCluster) {
      List<Story> jsonStoryClusterStories = jsonStoryCluster.stories;
      Iterable<String> jsonStoryClusterStoryIds =
          jsonStoryClusterStories.map((Story story) => story.id.value);

      /// Find a story cluster with all or some of the stories this cluster
      /// has.
      StoryCluster bestMatchingStoryCluster = _findBestMatchingStoryCluster(
        jsonStoryCluster,
        oldStoryClusters,
      );

      /// If such a cluster exists, replace its stories with the json cluster's
      /// stories.
      if (bestMatchingStoryCluster != null) {
        oldStoryClusters.remove(bestMatchingStoryCluster);
        newStoryClusters.add(bestMatchingStoryCluster);
        bestMatchingStoryCluster.update(jsonStoryCluster);
        return;
      }

      /// If no clusters exist with the stories, create a new cluster.
      StoryCluster newStoryCluster = new StoryCluster(
        stories: jsonStoryClusterStoryIds
            .map((String storyId) => currentStoriesMap[storyId])
            .toList(),
        onStoryClusterChanged: _onStoryClusterChange,
      );
      newStoryClusters.add(newStoryCluster);
      newStoryCluster.update(jsonStoryCluster);
    });

    /// We've merged all the clusters, update everyone with the new list.
    _storyClusters.clear();
    _storyClusters.addAll(newStoryClusters);
    _notifyListeners();
  }

  /// Finds the story cluster in [storyClusters] that best matches the stories
  /// in [storyClusterToMatch].
  StoryCluster _findBestMatchingStoryCluster(
    StoryCluster storyClusterToMatch,
    List<StoryCluster> storyClusters,
  ) {
    Map<String, Story> storyMap = <String, Story>{};
    storyClusterToMatch.stories.forEach(
      (Story story) => storyMap[story.id.value] = story,
    );

    /// Find story clusters with same set of stories...
    Iterable<StoryCluster> exactMatchingStoryClusters =
        storyClusters.where((StoryCluster storyCluster) {
      return storyCluster.stories.length == storyMap.length &&
          storyCluster.stories.every(
            (Story story) => storyMap.containsKey(story.id.value),
          );
    });

    assert(exactMatchingStoryClusters.length <= 1);

    if (exactMatchingStoryClusters.isNotEmpty) {
      return exactMatchingStoryClusters.first;
    }

    /// If we don't have an exact match, search for the best match.
    int bestMatchingStories = 0;
    StoryCluster bestStoryCluster;

    storyClusters.forEach((StoryCluster storyCluster) {
      int matchingStories = 0;
      storyCluster.stories.forEach((Story story) {
        if (storyMap.containsKey(story.id.value)) {
          matchingStories++;
        }
      });
      if (matchingStories > bestMatchingStories) {
        bestMatchingStories = matchingStories;
        bestStoryCluster = storyCluster;
      }
    });

    return bestStoryCluster;
  }

  List<StoryCluster> _getStoryClustersFromJson(String json) {
    Map<String, dynamic> decodedJson = JSON.decode(json);

    List<StoryCluster> jsonStoryClusters = <StoryCluster>[];

    if (decodedJson != null) {
      decodedJson['story_clusters']?.forEach(
        (Map<String, dynamic> storyClusterJson) => jsonStoryClusters.add(
              new StoryCluster.fromJson(storyClusterJson),
            ),
      );
    }

    return jsonStoryClusters;
  }

  /// Removes all the stories in the [StoryCluster] with [storyClusterId] from
  /// the [StoryProvider].
  void removeStoryCluster(StoryClusterId storyClusterId) {
    StoryCluster storyCluster = _storyClusters
        .where((StoryCluster storyCluster) => storyCluster.id == storyClusterId)
        .single;
    storyCluster.stories.forEach((Story story) {
      _storyProvider.deleteStory(story.id.value, () {});
      _removeStory(story.id.value, notify: false);
    });
    _storyClusters.remove(storyCluster);

    _notifyListeners();
  }

  /// Loads the list of previous stories from the [StoryProvider].
  /// If no stories exist, we create some.
  /// If stories do exist, we resume them.
  /// If set, [callback] will be called when the stories have been updated.
  void update([VoidCallback callback]) {
    _storyProvider.previousStories((List<String> storyIds) {
      if (storyIds.isEmpty && storyClusters.isEmpty) {
        _onUpdateComplete(callback);
        return;
      }

      // Remove any stories that aren't in the previous story list.
      _currentStories
          .where((Story story) => !storyIds.contains(story.id.value))
          .toList()
          .forEach((Story story) {
        log.info('Story ${story.id.value} has been removed!');
        _removeStoryFromClusters(story);
      });

      // Add only those stories we don't already know about.
      final List<String> storiesToAdd =
          storyIds.where((String storyId) => !containsStory(storyId)).toList();

      if (storiesToAdd.isEmpty) {
        _onUpdateComplete(callback);
        return;
      }

      // We have previous stories so lets resume them so they can be
      // displayed in a child view.
      int added = 0;
      storiesToAdd.forEach((String storyId) {
        _getController(storyId);
        _storyControllerMap[storyId]
            .getInfo((StoryInfo storyInfo, StoryState state) {
          _startStory(storyInfo, _storyClusters.length);
          added++;
          if (added == storiesToAdd.length) {
            _onUpdateComplete(callback);
          }
        });
      });
    });
  }

  void _onUpdateComplete(VoidCallback callback) {
    if (_firstTime) {
      _firstTime = false;
      _writeStoryClusterUpdatesToLink = true;
      _reactToLinkUpdates = true;
      _onLinkUpdate();
      onStoriesFirstAvailable();
    }
    callback?.call();
  }

  /// TODO: Determine if this should be expanding cluster.realStories instead
  Iterable<Story> get _currentStories => storyClusters.expand(
        (StoryCluster cluster) => cluster.stories,
      );

  /// Returns true if [storyId] is in the list of current stories.
  bool containsStory(String storyId) => _currentStories.any(
        (Story story) => story.id == new StoryId(storyId),
      );

  void _onStoryChanged(StoryInfo storyInfo, StoryState storyState) {
    if (!_storyControllerMap.containsKey(storyInfo.id)) {
      assert(
          storyState == StoryState.initial || storyState == StoryState.stopped);
      _getController(storyInfo.id);
      _startStory(storyInfo, 0);
    } else {
      storyClusters.forEach((StoryCluster storyCluster) {
        Story story = storyCluster.getStory(storyInfo.id);
        if (story != null) {
          DateTime lastInteraction = new DateTime.fromMicrosecondsSinceEpoch(
            (storyInfo.lastFocusTime / 1000).round(),
          );
          bool lastInteractionChanged =
              (lastInteraction != story.lastInteraction ||
                  lastInteraction != storyCluster.lastInteraction);
          story.lastInteraction = lastInteraction;
          storyCluster.lastInteraction = lastInteraction;
          if (lastInteractionChanged) {
            _notifyListeners();
          }
        }
      });
    }
    _onLinkUpdate();
  }

  void _removeStory(String storyId, {bool notify: true}) {
    if (_storyControllerMap.containsKey(storyId)) {
      _storyControllerMap[storyId].ctrl.close();
      _storyControllerMap.remove(storyId);
      Iterable<Story> stories = _currentStories.where(
        (Story story) => story.id.value == storyId,
      );
      assert(stories.length <= 1);
      if (stories.isNotEmpty) {
        _removeStoryFromClusters(stories.first);
      }
      if (notify) {
        _notifyListeners();
      }
    }
  }

  void _removeStoryFromClusters(Story story) {
    storyClusters
        .where(
            (StoryCluster storyCluster) => storyCluster.stories.contains(story))
        .toList()
        .forEach((StoryCluster storyCluster) {
      if (storyCluster.stories.length == 1) {
        _storyClusters.remove(storyCluster);
        _notifyListeners();
      } else {
        storyCluster.absorb(story);
      }
    });
  }

  void _getController(String storyId) {
    final StoryControllerProxy controller = new StoryControllerProxy();
    _storyControllerMap[storyId] = controller;
    _storyProvider.getController(
      storyId,
      controller.ctrl.request(),
    );
  }

  void _startStory(StoryInfo storyInfo, int startingIndex) {
    log.info('Adding story: $storyInfo');

    // Start it!

    // Create a flutter view from its view!
    StoryCluster storyCluster = new StoryCluster(
      stories: <Story>[
        _createStory(
          storyInfo: storyInfo,
          storyController: _storyControllerMap[storyInfo.id],
          startingIndex: startingIndex,
        ),
      ],
      onStoryClusterChanged: _onStoryClusterChange,
    );

    _storyClusters.add(storyCluster);
    _notifyListeners();
  }

  void _notifyListeners() {
    _listeners.toList().forEach((VoidCallback listener) => listener());
    _onStoryClusterChange();
  }

  void _onStoryClusterChange() {
    if (!_writeStoryClusterUpdatesToLink) {
      log.fine('Aborting link write, not ready!');
      return;
    }

    // If any of the story clusters that aren't placeholders have a place
    // holder story inside the current clustering state is invalid - don't write
    // it out to the link.
    if (_storyClusters
        .where((StoryCluster storyCluster) => !storyCluster.isPlaceholder)
        .any(
          (StoryCluster storyCluster) =>
              storyCluster.stories.any((Story story) => story.isPlaceHolder),
        )) {
      String json = JSON.encode(
        <String, List<StoryCluster>>{
          'story_clusters': _storyClusters
              .where((StoryCluster storyCluster) =>
                  !storyCluster.isPlaceholder &&
                  storyCluster.stories
                      .any((Story story) => story.isPlaceHolder))
              .toList()
        },
      );
      log.fine('Aborting link write, placeholder story found!\n$json');
      return;
    }

    String json = JSON.encode(
      <String, dynamic>{
        'story_clusters': _storyClusters
            .where((StoryCluster storyCluster) => !storyCluster.isPlaceholder)
            .toList(),
      },
    );

    if (json != _lastLinkJson) {
      log.fine('Writing to link!');
      _link.set(null, json);
      _lastLinkJson = json;
    }
  }

  Story _createStory({
    StoryInfo storyInfo,
    StoryController storyController,
    int startingIndex,
  }) {
    String storyTitle = Uri
        .parse(storyInfo.url)
        .pathSegments[Uri.parse(storyInfo.url).pathSegments.length - 1]
        ?.toUpperCase();

    // Add story ID to title only when we're in debug mode.
    assert(() {
      storyTitle = '[$storyTitle // ${storyInfo.id}]';
      return true;
    });
    int initialIndex = startingIndex;

    return new Story(
        id: new StoryId(storyInfo.id),
        builder: (BuildContext context) => new _StoryWidget(
              key: new GlobalObjectKey<_StoryWidgetState>(storyController),
              storyInfo: storyInfo,
              storyController: storyController,
              startingIndex: initialIndex,
            ),
        // TODO(apwilson): Improve title.
        title: storyTitle,
        icons: <OpacityBuilder>[],
        lastInteraction: new DateTime.fromMicrosecondsSinceEpoch(
          (storyInfo.lastFocusTime / 1000).round(),
        ),
        cumulativeInteractionDuration: new Duration(
          minutes: 0,
        ),
        themeColor:
            // TODO: Determine if we want to use color from story info.
            storyInfo.extra['color'] == null
                ? Colors.grey[500]
                : new Color(int.parse(storyInfo.extra['color'])),
        onClusterIndexChanged: (int clusterIndex) {
          _StoryWidgetState state =
              new GlobalObjectKey<_StoryWidgetState>(storyController)
                  .currentState;
          if (state != null) {
            state.index = clusterIndex;
          } else {
            initialIndex = clusterIndex;
          }
        });
  }
}

class _StoryWidget extends StatefulWidget {
  final StoryInfo storyInfo;
  final StoryController storyController;
  final int startingIndex;

  _StoryWidget({
    Key key,
    this.storyInfo,
    this.storyController,
    this.startingIndex,
  })
      : super(key: key);

  @override
  _StoryWidgetState createState() => new _StoryWidgetState();
}

class _StoryWidgetState extends State<_StoryWidget> {
  Completer<Null> _stoppingCompleter;
  ChildViewConnection _childViewConnection;
  int _currentIndex;
  bool _shouldBeStopped = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startingIndex;
    _toggleStartOrStop();
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<HitTestModel>(
      builder: (
        BuildContext context,
        Widget child,
        HitTestModel hitTestModel,
      ) =>
          _childViewConnection == null
              ? new Offstage()
              : new ChildView(
                  hitTestable:
                      hitTestModel.isStoryHitTestable(widget.storyInfo.id),
                  connection: _childViewConnection,
                ),
    );
  }

  set index(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      _toggleStartOrStop();
    }
  }

  void _toggleStartOrStop() {
    if (_currentIndex < _kMaxActiveClusters) {
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    _shouldBeStopped = false;
    if (_childViewConnection == null) {
      if (_stoppingCompleter != null) {
        _stoppingCompleter.future.then((_) => _startStory);
      } else {
        _startStory();
      }
    }
  }

  void _startStory() {
    if (_shouldBeStopped) {
      return;
    }
    log.info('Starting story: ${widget.storyInfo.id}');
    bindings.InterfacePair<ViewOwner> viewOwner =
        new bindings.InterfacePair<ViewOwner>();
    widget.storyController.start(viewOwner.passRequest());
    setState(() {
      _childViewConnection = new ChildViewConnection(
        viewOwner.passHandle(),
      );
    });
  }

  void _stop() {
    _shouldBeStopped = true;
    if (_childViewConnection != null) {
      if (_stoppingCompleter != null) {
        return;
      }
      _stoppingCompleter = new Completer<Null>();
      log.info('Stopping story: ${widget.storyInfo.id}');
      setState(() {
        _childViewConnection = null;
      });
      widget.storyController.stop(() {
        _stoppingCompleter.complete();
        _stoppingCompleter = null;
      });
    }
  }
}

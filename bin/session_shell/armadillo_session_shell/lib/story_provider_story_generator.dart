// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:armadillo/recent.dart';
import 'package:fidl/fidl.dart' as bindings;
import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:zircon/zircon.dart';

import 'hit_test_model.dart';
import 'story_provider_watcher_impl.dart';

const int _kMaxActiveClusters = 6;

const String _kStoryClustersLinkKey = 'story_clusters';

/// Creates a list of stories for the StoryList using
/// modular's [StoryProvider].
class StoryProviderStoryGenerator extends ChangeNotifier {
  bool _firstTime = true;
  bool _writeStoryClusterUpdatesToLink = false;
  bool _reactToLinkUpdates = false;
  bool _dragging = false;
  String _lastLinkJson;
  String _lastProcessedLinkJson;

  /// Set from an external source - typically the SessionShell.
  StoryProviderProxy _storyProvider;

  /// Set from an external source - typically the SessionShell.
  Link _link;

  final List<StoryCluster> _storyClusters = <StoryCluster>[];

  final Map<String, StoryControllerProxy> _storyControllerMap =
      <String, StoryControllerProxy>{};

  final StoryProviderWatcherBinding _storyProviderWatcherBinding =
      new StoryProviderWatcherBinding();

  /// Called the first time the [StoryProvider] returns stories.
  final VoidCallback onStoriesFirstAvailable;

  /// Call when a story cluster begins focusing.
  final VoidCallback onStoryClusterFocusStarted;

  /// Call when a story cluster finishes focusing.
  final ValueChanged<StoryCluster> onStoryClusterFocusCompleted;

  /// Constructor.
  StoryProviderStoryGenerator({
    this.onStoriesFirstAvailable,
    this.onStoryClusterFocusStarted,
    this.onStoryClusterFocusCompleted,
  });

  /// Call to close all the handles opened by this story generator.
  void close() {
    _storyProviderWatcherBinding.close();
    for (StoryControllerProxy storyControllerProxy
        in _storyControllerMap.values) {
      storyControllerProxy.ctrl.close();
    }
  }

  /// Sets the [StoryProvider] used to get and start stories.
  set storyProvider(StoryProviderProxy storyProvider) {
    _storyProvider = storyProvider
      ..watch(
        _storyProviderWatcherBinding.wrap(
          new StoryProviderWatcherImpl(
            onStoryChanged: _onStoryChanged,
            onStoryDeleted: _removeStory,
          ),
        ),
      );
    update();
  }

  /// Sets the [Link] used to set clustering information.
  set link(Link link) {
    _link = link;
  }

  /// The list of [StoryCluster]s.
  List<StoryCluster> get storyClusters =>
      new UnmodifiableListView<StoryCluster>(
        _storyClusters,
      );

  /// Called when the drag state of a cluster changes.
  void onDraggingChanged({bool dragging}) {
    if (dragging != _dragging) {
      _dragging = dragging;
      _onLinkUpdate();
    }
  }

  /// Called when the link changes.
  void onLinkChanged(String encoded) {
    dynamic decodedJson = json.decode(encoded);
    if (decodedJson == null ||
        !(decodedJson is Map) ||
        !decodedJson.containsKey(_kStoryClustersLinkKey)) {
      return;
    }
    String storyClustersJson = json.encode(decodedJson[_kStoryClustersLinkKey]);
    if (storyClustersJson == _lastLinkJson) {
      return;
    }

    log.fine('Link changed: $storyClustersJson');

    _lastLinkJson = storyClustersJson;

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
      'Current cluster count: ${_storyClusters.length}, '
          'decoded cluster count: ${jsonStoryClusters.length}',
    );

    /// If the list of stories doesn't match the canonical list of stories, do nothing.
    Iterable<Story> jsonStories = jsonStoryClusters.expand(
      (StoryCluster cluster) => cluster.stories,
    );

    Map<String, Story> currentStoriesMap = <String, Story>{};

    for (Story story in _currentStories) {
      currentStoriesMap[story.id.value] = story;
    }

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
    for (StoryCluster jsonStoryCluster in jsonStoryClusters) {
      List<Story> jsonStoryClusterStories = jsonStoryCluster.stories;
      List<Story> replacementStories = <Story>[];
      for (Story jsonStory in jsonStoryClusterStories) {
        Story replacementStory = currentStoriesMap[jsonStory.id.value]
            .copyWithPanelAndClusterIndex(jsonStory);
        replacementStories.add(replacementStory);
      }
      jsonStoryCluster.replaceStories(replacementStories);
    }

    List<StoryCluster> oldStoryClusters = _storyClusters.toList();
    List<StoryCluster> newStoryClusters = <StoryCluster>[];

    /// For each json story cluster...
    for (StoryCluster jsonStoryCluster in jsonStoryClusters) {
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
        continue;
      }

      /// If no clusters exist with the stories, create a new cluster.
      StoryCluster newStoryCluster = new StoryCluster(
        stories: jsonStoryClusterStoryIds
            .map((String storyId) => currentStoriesMap[storyId])
            .toList(),
        onStoryClusterChanged: _onStoryClusterChange,
      );
      newStoryCluster.focusModel
        ..onStoryClusterFocusStarted = onStoryClusterFocusStarted
        ..onStoryClusterFocusCompleted = () => onStoryClusterFocusCompleted(
              newStoryCluster,
            );
      newStoryClusters.add(newStoryCluster);
      newStoryCluster.update(jsonStoryCluster);
    }

    /// We've merged all the clusters, update everyone with the new list.
    _storyClusters
      ..clear()
      ..addAll(newStoryClusters);

    notifyListeners();
  }

  /// Finds the story cluster in [storyClusters] that best matches the stories
  /// in [storyClusterToMatch].
  StoryCluster _findBestMatchingStoryCluster(
    StoryCluster storyClusterToMatch,
    List<StoryCluster> storyClusters,
  ) {
    Map<String, Story> storyMap = <String, Story>{};
    for (Story story in storyClusterToMatch.stories) {
      storyMap[story.id.value] = story;
    }

    /// Find story clusters with same set of stories...
    Iterable<StoryCluster> exactMatchingStoryClusters = storyClusters.where(
      (StoryCluster storyCluster) =>
          storyCluster.stories.length == storyMap.length &&
          storyCluster.stories.every(
            (Story story) => storyMap.containsKey(story.id.value),
          ),
    );

    assert(exactMatchingStoryClusters.length <= 1);

    if (exactMatchingStoryClusters.isNotEmpty) {
      return exactMatchingStoryClusters.first;
    }

    /// If we don't have an exact match, search for the best match.
    int bestMatchingStories = 0;
    StoryCluster bestStoryCluster;

    for (StoryCluster storyCluster in storyClusters) {
      int matchingStories = 0;
      for (Story story in storyCluster.stories) {
        if (storyMap.containsKey(story.id.value)) {
          matchingStories++;
        }
      }
      if (matchingStories > bestMatchingStories) {
        bestMatchingStories = matchingStories;
        bestStoryCluster = storyCluster;
      }
    }

    return bestStoryCluster;
  }

  List<StoryCluster> _getStoryClustersFromJson(String encoded) {
    List<dynamic> decodedJson = json.decode(encoded);

    List<StoryCluster> jsonStoryClusters = <StoryCluster>[];

    if (decodedJson != null) {
      for (Map<String, dynamic> storyClusterJson in decodedJson) {
        jsonStoryClusters.add(new StoryCluster.fromJson(storyClusterJson));
      }
    }

    return jsonStoryClusters;
  }

  /// Removes all the stories in the [StoryCluster] with [storyClusterId] from
  /// the [StoryProvider].
  void onDeleteStoryCluster(StoryClusterId storyClusterId) {
    StoryCluster storyCluster = _storyClusters
        .where((StoryCluster storyCluster) => storyCluster.id == storyClusterId)
        .single;
    for (Story story in storyCluster.stories) {
      log..info('Deleting story ${story.id.value}...')
         ..severe('Not deleting story because Armadillo has not been converted to puppet master.');
      /*
      _storyProvider.deleteStory(story.id.value, () {
        log.info('Story ${story.id.value} deleted!');
      });
      */

      if (_storyControllerMap.containsKey(story.id.value)) {
        _storyControllerMap[story.id.value].ctrl.close();
        _storyControllerMap.remove(story.id.value);
      }
    }
    _storyClusters.remove(storyCluster);

    notifyListeners();
  }

  /// Called when a story cluster is added due to user interaction.
  void onStoryClusterAdded(StoryCluster storyCluster) {
    _storyClusters.add(storyCluster);
    notifyListeners();
  }

  /// Called when a story cluster is removed due to user interaction.
  void onStoryClusterRemoved(StoryCluster storyCluster) {
    _storyClusters.remove(storyCluster);
    notifyListeners();
  }

  /// Loads the list of previous stories from the [StoryProvider].
  /// If no stories exist, we create some.
  /// If stories do exist, we resume them.
  /// If set, [callback] will be called when the stories have been updated.
  void update([VoidCallback callback]) {
    _storyProvider.previousStories((List<StoryInfo> storyInfos) {
      if (storyInfos.isEmpty && _storyClusters.isEmpty) {
        _onUpdateComplete(callback);
        return;
      }

      // Remove any stories that aren't in the previous story list.
      for (Story story in _currentStories
          .where((Story story) => !storyInfos
              .map((StoryInfo info) => info.id)
              .contains(story.id.value))
          .toList()) {
        log.info('Story ${story.id.value} has been removed!');
        _removeStoryFromClusters(story);
      }

      // Add only those stories we don't already know about.
      final List<String> storiesToAdd = storyInfos
          .map((StoryInfo info) => info.id)
          .where((String storyId) => !containsStory(storyId))
          .toList();

      if (storiesToAdd.isEmpty) {
        _onUpdateComplete(callback);
        return;
      }

      // We have previous stories so lets resume them so they can be
      // displayed in a child view.
      int added = 0;
      for (String storyId in storiesToAdd) {
        _getController(storyId);
        _storyControllerMap[storyId].getInfo((
          StoryInfo storyInfo,
          StoryState state,
        ) {
          _startStory(storyInfo, _storyClusters.length);
          added++;
          if (added == storiesToAdd.length) {
            _onUpdateComplete(callback);
          }
        });
      }
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
  Iterable<Story> get _currentStories => _storyClusters.expand(
        (StoryCluster cluster) => cluster.stories,
      );

  /// Returns true if [storyId] is in the list of current stories.
  bool containsStory(String storyId) => _currentStories.any(
        (Story story) => story.id == new StoryId(storyId),
      );

  void _onStoryChanged(StoryInfo storyInfo, StoryState storyState) {
    if (!_storyControllerMap.containsKey(storyInfo.id)) {
      assert(storyState == StoryState.stopped);
      _getController(storyInfo.id);
      _startStory(storyInfo, 0);
    } else {
      for (StoryCluster storyCluster in _storyClusters) {
        Story story = storyCluster.getStory(storyInfo.id);
        if (story != null) {
          DateTime lastInteraction = new DateTime.fromMicrosecondsSinceEpoch(
            (storyInfo.lastFocusTime / 1000).round(),
          );

          // Ignore if we're going back in time.
          if (lastInteraction.isAfter(story.lastInteraction)) {
            bool lastInteractionChanged =
                lastInteraction != story.lastInteraction ||
                    lastInteraction != storyCluster.lastInteraction;
            story.lastInteraction = lastInteraction;
            storyCluster.lastInteraction = lastInteraction;
            if (lastInteractionChanged) {
              notifyListeners();
            }
          }
        }
      }
    }
    _onLinkUpdate();
  }

  void _removeStory(String storyId, {bool notify = true}) {
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
        notifyListeners();
      }
    }
  }

  void _removeStoryFromClusters(Story story) {
    for (StoryCluster storyCluster in _storyClusters
        .where(
          (StoryCluster storyCluster) => storyCluster.stories.contains(story),
        )
        .toList()) {
      if (storyCluster.stories.length == 1) {
        _storyClusters.remove(storyCluster);
        notifyListeners();
      } else {
        storyCluster.absorb(story);
      }
    }
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
    log.info('Adding story: $storyInfo $startingIndex');

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
      storyClusterEntranceTransitionModel:
          new StoryClusterEntranceTransitionModel(
        completed: false,
      ),
    );
    storyCluster.focusModel
      ..onStoryClusterFocusStarted = onStoryClusterFocusStarted
      ..onStoryClusterFocusCompleted = () => onStoryClusterFocusCompleted(
            storyCluster,
          );
    _storyClusters.add(storyCluster);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
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
      String encoded = json.encode(
        _storyClusters
            .where((StoryCluster storyCluster) =>
                !storyCluster.isPlaceholder &&
                storyCluster.stories.any((Story story) => story.isPlaceHolder))
            .toList(),
      );
      log.fine('Aborting link write, placeholder story found!\n$encoded');
      return;
    }

    String encoded = json.encode(
      _storyClusters
          .where((StoryCluster storyCluster) => !storyCluster.isPlaceholder)
          .toList(),
    );

    if (encoded != _lastLinkJson) {
      log.fine('Writing to link!');
      var jsonList = Uint8List.fromList(utf8.encode(encoded));
      var data = fuchsia_mem.Buffer(
        vmo: new SizedVmo.fromUint8List(jsonList),
        size: jsonList.length,
      );
      _link.set(<String>[_kStoryClustersLinkKey], data);
      _lastLinkJson = encoded;
    }
  }

  Story _createStory({
    StoryInfo storyInfo,
    StoryController storyController,
    int startingIndex,
  }) {
    String storyTitle = _getStoryTitle(storyInfo);
    _StoryWidgetModel storyWidgetState = new _StoryWidgetModel(
      storyInfo: storyInfo,
      storyController: storyController,
      startingIndex: startingIndex,
    );

    // TODO: Determine if we want to use color from story info.
    final String color = _getStoryInfoExtraValue(storyInfo, 'color');
    return new Story(
        id: new StoryId(storyInfo.id),
        widget: new _StoryWidget(model: storyWidgetState),
        // TODO(apwilson): Improve title.
        title: storyTitle,
        icons: <OpacityBuilder>[],
        lastInteraction: new DateTime.fromMicrosecondsSinceEpoch(
          (storyInfo.lastFocusTime / 1000).round(),
        ),
        cumulativeInteractionDuration: const Duration(
          minutes: 0,
        ),
        themeColor:
            color == null ? Colors.grey[500] : new Color(int.parse(color)),
        onClusterIndexChanged: (int clusterIndex) {
          storyWidgetState.index = clusterIndex;
        });
  }

  String _getStoryTitle(StoryInfo storyInfo) {
    String storyTitle;
    final String extraTitle = _getStoryInfoExtraValue(storyInfo, 'story_title');
    if (extraTitle != null) {
      storyTitle = extraTitle;
    } else if (storyInfo.url != null) {
      storyTitle = Uri.parse(storyInfo.url)
          .pathSegments[Uri.parse(storyInfo.url).pathSegments.length - 1]
          ?.toUpperCase();
    } else {
      storyTitle = '<no title>';
    }

    // Add story ID to title only when we're in debug mode.
    assert(() {
      storyTitle = '[$storyTitle // ${storyInfo.id}]';
      return true;
    }());
    return storyTitle;
  }

  String _getStoryInfoExtraValue(StoryInfo storyInfo, final String key) {
    if (storyInfo.extra != null) {
      for (final StoryInfoExtraEntry entry in storyInfo.extra) {
        if (entry.key == key) {
          return entry.value;
        }
      }
    }
    return null;
  }
}

class _StoryWidgetModel extends Model {
  final StoryInfo storyInfo;
  final StoryController storyController;

  _StoryWidgetModel({this.storyInfo, this.storyController, int startingIndex}) {
    _currentIndex = startingIndex;
    _toggleStartOrStop();
  }

  Completer<Null> _stoppingCompleter;
  ChildViewConnection _childViewConnection;
  int _currentIndex;
  bool _shouldBeStopped = true;

  ChildViewConnection get childViewConnection => _childViewConnection;

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
    log.info('Starting story: ${storyInfo.id}');
    bindings.InterfacePair<ViewOwner> viewOwner =
        new bindings.InterfacePair<ViewOwner>();
    storyController.start(viewOwner.passRequest());
    _childViewConnection = new ChildViewConnection(
      viewOwner.passHandle(),
    );
    notifyListeners();
  }

  void _stop() {
    _shouldBeStopped = true;
    if (_childViewConnection != null) {
      if (_stoppingCompleter != null) {
        return;
      }
      _stoppingCompleter = new Completer<Null>();
      log.info('Stopping story: ${storyInfo.id}');
      _childViewConnection = null;
      notifyListeners();
      storyController.stop(() {
        _stoppingCompleter.complete();
        _stoppingCompleter = null;
      });
    }
  }
}

class _StoryWidget extends StatelessWidget {
  final _StoryWidgetModel model;

  const _StoryWidget({this.model});

  @override
  Widget build(BuildContext context) => new AnimatedBuilder(
        animation: model,
        builder: (BuildContext context, Widget child) =>
            new ScopedModelDescendant<HitTestModel>(
              builder: (
                BuildContext context,
                Widget child,
                HitTestModel hitTestModel,
              ) =>
                  model.childViewConnection == null
                      ? const Offstage()
                      : new ChildView(
                          hitTestable: hitTestModel
                              .isStoryHitTestable(model.storyInfo.id),
                          connection: model.childViewConnection,
                        ),
            ),
      );
}

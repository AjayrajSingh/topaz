// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/widgets.dart' show ChangeNotifier;

import 'package:armadillo/story_cluster.dart';
import 'package:armadillo/story.dart';
import 'package:collection/collection.dart';

const ListEquality<String> _kStringListEquality = const ListEquality<String>();

/// Tracks the set of focused stories.
class FocusedStoriesTracker extends ChangeNotifier {
  StoryCluster _lastFocusedStoryCluster;
  List<String> _focusedStoryIds = const <String>[];
  String _focusedStoryId;

  /// Call when the currently focused StoryCluster changes.
  void onStoryClusterFocusChanged(StoryCluster storyCluster) {
    _lastFocusedStoryCluster?.removeStoryListListener(_onStoryListChanged);
    storyCluster?.addStoryListListener(_onStoryListChanged);
    _lastFocusedStoryCluster = storyCluster;
    _onStoryListChanged();
  }

  /// Call when the list of StoryClusters changes.
  void onStoryClusterListChanged(List<StoryCluster> storyClusters) {
    if (_lastFocusedStoryCluster != null) {
      StoryCluster storyClusterWithId = storyClusters.firstWhere(
        (StoryCluster storyCluster) =>
            storyCluster.id == _lastFocusedStoryCluster.id,
        orElse: () => null,
      );

      _lastFocusedStoryCluster?.removeStoryListListener(_onStoryListChanged);
      _lastFocusedStoryCluster = storyClusterWithId;
      _lastFocusedStoryCluster?.addStoryListListener(_onStoryListChanged);

      _onStoryListChanged();
    }
  }

  /// The current list of focused story ids.
  List<String> get focusedStoryIds =>
      new UnmodifiableListView<String>(_focusedStoryIds);

  /// The currently focused story id of the list of focused story ids.  Null if
  /// no stories are focused.
  String get focusedStoryId => _focusedStoryId;

  void _onStoryListChanged() {
    List<String> newFocusedStoryIds = (_lastFocusedStoryCluster?.stories
            ?.map<String>((Story story) => story.id.value)
            ?.toList() ??
        <String>[])
      ..sort();
    String newFocusedStoryId = _lastFocusedStoryCluster?.focusedStoryId?.value;
    if (!_kStringListEquality.equals(_focusedStoryIds, newFocusedStoryIds) ||
        newFocusedStoryId != _focusedStoryId) {
      _focusedStoryIds = newFocusedStoryIds;
      _focusedStoryId = newFocusedStoryId;
      notifyListeners();
    }
  }
}

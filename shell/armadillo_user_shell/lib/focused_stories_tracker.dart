// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:armadillo/recent.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;

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
    /// Only real stories are valid for story focus/visibility purposes.
    List<String> newFocusedStoryIds = (_lastFocusedStoryCluster?.realStories
            ?.map<String>((Story story) => story.id.value)
            ?.toList() ??
        <String>[])
      ..sort();
    String newFocusedStoryId = _lastFocusedStoryCluster?.focusedStoryId?.value;

    /// Ensure we're not focused on a place holder story.
    if (!newFocusedStoryIds.contains(newFocusedStoryId)) {
      newFocusedStoryId = null;
    }
    if (!_kStringListEquality.equals(_focusedStoryIds, newFocusedStoryIds) ||
        newFocusedStoryId != _focusedStoryId) {
      _focusedStoryIds = newFocusedStoryIds;
      _focusedStoryId = newFocusedStoryId;
      notifyListeners();
    }
  }
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';

/// Called when the story with [storyInfo] has changed.
typedef OnStoryChanged = void Function(StoryInfo storyInfo, StoryState state);

/// Called when the story with [storyId] has been deleted.
typedef OnStoryDeleted = void Function(String storyId);

/// Watches for changes to the [StoryProvider].
class StoryProviderWatcherImpl extends StoryProviderWatcher {
  /// Called when a story has changed.
  final OnStoryChanged onStoryChanged;

  /// Called when a story has been deleted.
  final OnStoryDeleted onStoryDeleted;

  /// Constructor.
  StoryProviderWatcherImpl({this.onStoryChanged, this.onStoryDeleted});

  @override
  void onChange(
    StoryInfo storyInfo,
    StoryState storyState,
    StoryVisibilityState storyVisibilityState,
    bool handleBackGesture,
  ) {
    // TODO(SY-684): Handle story visibility state changes.
    onStoryChanged?.call(storyInfo, storyState);
  }

  @override
  void onDelete(String storyId) {
    onStoryDeleted?.call(storyId);
  }
}

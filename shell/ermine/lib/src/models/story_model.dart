// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show StoryControllerProxy, StoryInfo;
import 'package:fidl_fuchsia_ui_views/fidl_async.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart'
    show ChildViewConnection;

/// Denotes the visual state of the story.
enum StoryVisualState { normal, minimized, maximized }

/// Denotes the type of story: Browser or Story.
enum StoryType { story, browser }

/// Manages the visual state of a story.
class StoryModel extends ChangeNotifier {
  /// The id of the story.
  final StoryInfo storyInfo;

  /// The type of the story.
  final StoryType storyType;

  /// The visual state of the story: normal, maximized or minimized.
  final ValueNotifier<StoryVisualState> visibility;

  /// Callback when the close button was tapped.
  final VoidCallback onDelete;

  /// Callback when the story was minimized (stopped).
  final VoidCallback onStopped;

  /// Holds the connection to the Story's view.
  ChildViewConnection childViewConnection;

  final StoryControllerProxy _storyController;

  /// Constructor.
  StoryModel({
    @required this.storyInfo,
    @required StoryControllerProxy storyController,
    this.onStopped,
    this.onDelete,
    this.storyType = StoryType.story,
    StoryVisualState visualState = StoryVisualState.normal,
  })  : _storyController = storyController,
        visibility = ValueNotifier(visualState);

  /// Returns true if story is not minimized.
  bool get isVisible => visibility.value != StoryVisualState.minimized;

  /// Returns true if the story is maximized.
  bool get isMaximized => visibility.value == StoryVisualState.maximized;

  /// Returns true if the story is maximized.
  bool get isMinimized => visibility.value == StoryVisualState.minimized;

  /// Called by [StoryManager] to start the story.
  void start() {
    _storyController.requestStart();
  }

  /// Called by [StoryManager] when story's view is available.
  void attachView(ViewHolderToken viewHolderToken) {
    childViewConnection = ChildViewConnection(viewHolderToken);
    notifyListeners();
  }

  /// Called by [StoryManager] to stop the story.
  void stop() {
    visibility.value = StoryVisualState.minimized;
    _storyController.stop().then((_) => onStopped());
  }

  /// Called by [StoryManager] to toggle fullscreen or immersive mode.
  set fullscreen(bool fullscreen) {
    visibility.value =
        fullscreen ? StoryVisualState.maximized : StoryVisualState.normal;
  }

  @override
  void dispose() {
    super.dispose();
    _storyController.ctrl.close();
  }

  /// Called when close button is tapped.
  void onClose() {
    onDelete?.call();
  }

  /// Called when the minimize button is tapped.
  void onMinimize() {
    stop();
  }

  /// Called when the maximize button is tapped.
  void onMaximize() {
    visibility.value = StoryVisualState.maximized;
  }

  /// Called when the restor button is tapped.
  void onRestore() {
    visibility.value = StoryVisualState.normal;
  }
}

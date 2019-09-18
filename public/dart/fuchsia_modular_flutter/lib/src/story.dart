// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';

/// Defines a class that represents a 'story' in Fuchsia. It holds state that
/// describe the current runtime characterstics of the story:
abstract class Story {
  /// Returns the unique id of the story.
  String get id;

  /// Returns the [StoryInfo] of the story.
  StoryInfo get info;

  /// Holds the focused state of the story.
  bool focused;

  /// Holds the runtime [StoryState] of the story.
  StoryState state;

  /// Holds the [StoryVisibilityState] of the story.
  StoryVisibilityState visibilityState;

  /// Holds the [ChildViewConnection] assigned to the story.
  ChildViewConnection childViewConnection;

  /// Request focus on this story instance.
  void focus();

  /// Stop the story.
  void stop();

  /// Delete this story instance.
  void delete();

  /// Callback when a module is added.
  void onModuleAdded(ModuleData moduleData);

  /// Callback when a module is focused.
  void onModuleFocused(List<String> modulePath);
}

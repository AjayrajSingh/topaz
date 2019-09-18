// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_ui_policy/fidl_async.dart' show Presentation;
import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show SessionShellContext, PuppetMaster;
import 'package:fuchsia_services/services.dart' show StartupContext;
import 'package:meta/meta.dart';

import 'session_shell/internal/_session_shell_2_impl.dart';
import 'story_2.dart';

/// Defines a class that encapsulates FIDL interfaces used to build a 'Session
/// Shell' for Fuchsia.
///
/// A Session Shell's primary responsibility is to display
/// and manage a set of [Story] instances. As such it provides a Session Shell
/// author a set of callbacks to be notified when a story is started, stopped
/// or changed. It allows stories to be deleted and focused. Only the
/// [onStoryStarted] callback is required, since it returns a concrete [Story].
///
/// This class is part of a soft-transition of [StoryInfo] from struct to table.
/// Clients should use [SessionShell] once [StoryInfo] is a table. See MF-481.
/// TODO(MF-481) Remove once StoryInfo transitioned to table
abstract class SessionShell2 {
  static SessionShell2 _sessionShell;

  /// Returns a shared instance of this.
  factory SessionShell2({
    @required StartupContext startupContext,
    @required Story2Factory onStoryStarted,
    Story2Callback onStoryChanged,
    Story2Callback onStoryDeleted,
  }) {
    return _sessionShell ??= SessionShell2Impl(
      startupContext: startupContext,
      onStoryStarted: onStoryStarted,
      onStoryChanged: onStoryChanged,
      onStoryDeleted: onStoryDeleted,
    );
  }

  /// An interable for stories in the session.
  Iterable<Story2> get stories;

  /// The [Story] that is currently focused. It could be [null].
  Story2 get focusedStory;

  /// Returns the [SessionShellContext].
  SessionShellContext get context;

  /// Returns the [Presentation] used by the session.
  Presentation get presentation;

  /// Returns the [PuppetMaster] used by the session.
  PuppetMaster get puppetMaster;

  /// Register this instance of Session Shell with modular framework. This
  /// needs to be called before any other methods.
  void start();

  /// Unregister and disconnect from modular framework.
  void stop();

  /// Request focus for story with [id]. Ensure [start] is called before
  /// invoking this method. Otherwise this is a no-op.
  void focusStory(String id);

  /// Delete the [Story] given the id. Ensure [start] is called before
  /// invoking this method. Otherwise this is a no-op.
  void deleteStory(String id);

  /// Stop the story with the id. Ensure [start] is called before
  /// invoking this method. Otherwise this is a no-op.
  void stopStory(String id);
}

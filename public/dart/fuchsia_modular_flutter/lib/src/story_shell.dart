// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fidl_fuchsia_app_discover/fidl_async.dart'
    show SessionDiscoverContextProxy, StoryDiscoverContext;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fuchsia_services/services.dart' show StartupContext;

import 'story_shell/internal/_story_shell_factory_impl.dart';
import 'surface.dart';

/// Defines an interface to represent a shell for a fuchsia story.
///
/// The [surfaces] iterable allows access to all the surfaces of mods held by
/// this story shell. The callbacks [onSurfaceAdded], [onSurfaceRemoved] and
/// [onSurfaceFocusChange] allow notification of changes to surfaces in the
/// shell.
///
/// To register the [modular.StoryShellFactory] with the modular framework, call
/// [advertise] and provide callbacks when instances of [StoryShell] are
/// attached or detached in the session shell.
abstract class StoryShell {
  /// The story identifier.
  String get id;

  /// An interable for surfaces in the story shell.
  Iterable<Surface> get surfaces;

  /// Callback when a [Surface] is added to the story shell.
  void onSurfaceAdded(Surface surface);

  /// Callback when a [Surface] is removed from the story shell.
  void onSurfaceRemoved(Surface surface);

  /// Callback when a [Surface] focus is changed.
  void onSurfaceFocusChange(Surface surface, {bool focus = false});

  static final modular.StoryShellFactoryBinding _storyShellFactoryBinding =
      modular.StoryShellFactoryBinding();

  /// Advertises [StoryShellFactory] to outgoing services.
  static void advertise({
    @required StartupContext startupContext,
    @required StoryShellFactory onStoryAttached,
    StoryShellCallback onStoryDetached,
  }) {
    final sessionDiscoverContext = SessionDiscoverContextProxy();
    startupContext.incoming.connectToService(sessionDiscoverContext);

    final storyShellFactory = StoryShellFactoryImpl(
      sessionDiscoverContext: sessionDiscoverContext,
      onStoryAttached: onStoryAttached,
      onStoryDetached: onStoryDetached,
    );
    startupContext.outgoing.addPublicService(
        (InterfaceRequest<modular.StoryShellFactory> request) =>
            _storyShellFactoryBinding.bind(storyShellFactory, request),
        modular.StoryShellFactory.$serviceName);
  }
}

/// Defines a soft-transition extension to [Story].
abstract class StoryShellTransitional extends StoryShell {
  /// Holds the [StoryDiscoverContext] to get/set properties.
  StoryDiscoverContext discoverContext;
}

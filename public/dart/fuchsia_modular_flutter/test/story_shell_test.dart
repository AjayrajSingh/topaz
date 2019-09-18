// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:test/test.dart';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_app_discover/fidl_async.dart'
    show SessionDiscoverContext, StoryDiscoverContext;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fuchsia_modular_flutter/story_shell.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:fuchsia_services/services.dart';
import 'package:mockito/mockito.dart';

// ignore: implementation_imports
import 'package:fuchsia_modular_flutter/src/story_shell/internal/_story_shell_factory_impl.dart';
// ignore: implementation_imports
import 'package:fuchsia_modular_flutter/src/story_shell/internal/_modular_story_shell_impl.dart';

void main() {
  test('Publish StoryShellFactory', () {
    final mockStartupContext = MockStartupContext();
    final mockOutgoingImpl = MockOutgoing();
    final mockIncomingImpl = MockIncoming();
    when(mockStartupContext.outgoing).thenReturn(mockOutgoingImpl);
    when(mockStartupContext.incoming).thenReturn(mockIncomingImpl);

    StoryShell.advertise(
      startupContext: mockStartupContext,
      onStoryAttached: (_) => null,
    );

    verify(mockOutgoingImpl.addPublicService(
        any, modular.StoryShellFactory.$serviceName));
    verify(mockIncomingImpl.connectToService(any));
  });

  test('Story Attached', () async {
    String storyId;
    final factory = TestStoryShellFactory(
      onStoryAttached: (id) {
        storyId = id;
        return TestStoryShell(id);
      },
    );

    final request = MockInterfaceRequest<modular.StoryShell>();
    await factory.attachStory('foo', request);

    expect(storyId, 'foo');
  });

  test('Story Detached', () async {
    StoryShell storyShell;
    final factory = TestStoryShellFactory(
      onStoryAttached: (id) => TestStoryShell(id),
      onStoryDetached: (shell) => storyShell = shell,
    );

    final request = MockInterfaceRequest<modular.StoryShell>();
    await factory.attachStory('foo', request);
    await factory.detachStory('foo');

    expect(storyShell.id, 'foo');
  });

  test('Surface Added', () async {
    TestStoryShell storyShell;
    final factory = TestStoryShellFactory(
      onStoryAttached: (id) => storyShell = TestStoryShell(id),
      onStoryDetached: (shell) => storyShell = shell,
    );

    final request = MockInterfaceRequest<modular.StoryShell>();
    await factory.attachStory('foo', request);
    await factory.storyShellImpl.addSurface(
        modular.ViewConnection(surfaceId: 'foo', viewHolderToken: null),
        MockSurfaceInfo());

    expect(storyShell.surfaceAdded, isNotNull);
    expect(storyShell.surfaceAdded.id, 'foo');
  });

  test('Surface Removed', () async {
    TestStoryShell storyShell;
    final factory = TestStoryShellFactory(
      onStoryAttached: (id) => storyShell = TestStoryShell(id),
      onStoryDetached: (shell) => storyShell = shell,
    );

    final request = MockInterfaceRequest<modular.StoryShell>();
    await factory.attachStory('foo', request);
    await factory.storyShellImpl.addSurface(
        modular.ViewConnection(surfaceId: 'foo', viewHolderToken: null),
        MockSurfaceInfo());
    await factory.storyShellImpl.removeSurface('foo');

    expect(storyShell.surfaceRemoved, isNotNull);
    expect(storyShell.surfaceRemoved.id, 'foo');
  });

  test('Surface Focused', () async {
    TestStoryShell storyShell;
    final factory = TestStoryShellFactory(
      onStoryAttached: (id) => storyShell = TestStoryShell(id),
      onStoryDetached: (shell) => storyShell = shell,
    );

    final request = MockInterfaceRequest<modular.StoryShell>();
    await factory.attachStory('foo', request);
    await factory.storyShellImpl.addSurface(
        modular.ViewConnection(surfaceId: 'foo', viewHolderToken: null),
        MockSurfaceInfo());
    await factory.storyShellImpl.focusSurface('foo');

    expect(storyShell.focus, true);
  });
}

class TestStoryShellFactory extends StoryShellFactoryImpl {
  ModularStoryShellImpl storyShellImpl;

  TestStoryShellFactory({
    SessionDiscoverContext sessionDiscoverContext,
    StoryShellFactory onStoryAttached,
    StoryShellCallback onStoryDetached,
  }) : super(
          sessionDiscoverContext: sessionDiscoverContext,
          onStoryAttached: onStoryAttached,
          onStoryDetached: onStoryDetached,
        );

  @override
  ModularStoryShellImpl newModularStoryShell(
    StoryShell storyShell,
    InterfaceRequest<modular.StoryShell> request,
  ) {
    return storyShellImpl = TestModularStoryShellImpl(storyShell);
  }

  @override
  Future<StoryDiscoverContext> getStoryDiscoverContext(String id) async {
    return null;
  }
}

class TestModularStoryShellImpl extends ModularStoryShellImpl {
  TestModularStoryShellImpl(StoryShell storyShell) : super(storyShell);

  @override
  ChildViewConnection newChildViewConnection(
      modular.ViewConnection viewConnection) {
    return null;
  }
}

class TestStoryShell implements StoryShell {
  Surface surfaceAdded, surfaceRemoved;
  bool focus;

  @override
  String id;

  TestStoryShell(this.id);

  @override
  void onSurfaceAdded(Surface surface) => surfaceAdded = surface;

  @override
  void onSurfaceFocusChange(Surface surface, {bool focus = false}) =>
      this.focus = focus;

  @override
  void onSurfaceRemoved(Surface surface) => surfaceRemoved = surface;

  @override
  Iterable<Surface> get surfaces => null;
}

// Mock classes.
class MockStartupContext extends Mock implements StartupContext {}

class MockIncoming extends Mock implements Incoming {}

class MockOutgoing extends Mock implements Outgoing {}

class MockModularStoryShellImpl extends Mock implements ModularStoryShellImpl {}

class MockInterfaceRequest<T> extends Mock implements InterfaceRequest<T> {}

class MockViewConnection extends Mock implements modular.ViewConnection {}

class MockSurfaceInfo extends Mock implements modular.SurfaceInfo {}

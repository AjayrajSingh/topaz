// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fuchsia_modular_flutter/session_shell.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:fuchsia_services/services.dart';
import 'package:mockito/mockito.dart';

// ignore: implementation_imports
import 'package:fuchsia_modular_flutter/src/session_shell/internal/_session_shell_impl.dart';

void main() {
  test('Create SessionShell', () {
    expect(
        SessionShell(
            startupContext: MockStartupContext(),
            onStoryStarted: ({
              modular.StoryInfo info,
              SessionShell sessionShell,
              modular.StoryController controller,
            }) {
              return TestStory()..info = info;
            }),
        isNotNull);
  });

  test('Start SessionShell', () {
    final mockStartupContext = MockStartupContext();
    final mockOutgoingImpl = MockOutgoing();
    when(mockStartupContext.outgoing).thenReturn(mockOutgoingImpl);

    TestSessionShell(startupContext: mockStartupContext).start();

    verify(mockOutgoingImpl.addPublicService(
        any, modular.SessionShell.$serviceName));
    verify(mockOutgoingImpl.addPublicService(
        any, modular.SessionShellPresentationProvider.$serviceName));
  });

  test('Story started', () {
    String startedStoryId;
    final sessionShell = TestSessionShell(onStoryStarted: ({
      modular.StoryInfo info,
      SessionShell sessionShell,
      modular.StoryController controller,
    }) {
      startedStoryId = info.id;
      return TestStory()..info = info;
    })
      ..onChange(
        modular.StoryInfo(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      );
    expect(startedStoryId, 'foo');
    verify(sessionShell.mockStoryController.requestStart());
  });

  test('Story deleted', () {
    String deletedStoryId;
    TestSessionShell(onStoryDeleted: (story) {
      deletedStoryId = story.id;
    })
      ..onChange(
        modular.StoryInfo(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      )
      ..deleteStory('foo');
    expect(deletedStoryId, 'foo');
  });

  test('Story changed', () {
    Story changedStory;
    TestSessionShell(onStoryChanged: (story) {
      changedStory = story;
    })
      ..onChange(
        modular.StoryInfo(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      )
      ..onChange(
        modular.StoryInfo(id: 'foo', lastFocusTime: 0),
        modular.StoryState.running,
        modular.StoryVisibilityState.default$,
      );
    expect(changedStory.id, 'foo');
    expect(changedStory.state, modular.StoryState.running);
  });

  test('Story focused', () {
    Story changedStory;
    TestSessionShell(onStoryChanged: (story) {
      changedStory = story;
    })
      ..onChange(
        modular.StoryInfo(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      )
      ..onFocusChange(modular.FocusInfo(
        focusedStoryId: 'foo',
        deviceId: '',
        lastFocusChangeTimestamp: 0,
      ));
    expect(changedStory.id, 'foo');
    expect(changedStory.focused, true);
  });
}

class TestSessionShell extends SessionShellImpl {
  MockSessionShellContext mockSessionShellContext = MockSessionShellContext();
  MockStoryProvider mockStoryProvider = MockStoryProvider();
  MockPuppetMaster mockPuppetMaster = MockPuppetMaster();
  MockStoryController mockStoryController = MockStoryController();

  TestSessionShell({
    StartupContext startupContext,
    StoryFactory onStoryStarted = _onStoryStarted,
    StoryCallback onStoryChanged,
    StoryCallback onStoryDeleted,
  }) : super(
          startupContext: startupContext ?? MockStartupContext(),
          onStoryStarted: onStoryStarted,
          onStoryDeleted: onStoryDeleted,
          onStoryChanged: onStoryChanged,
        );

  static Story _onStoryStarted({
    modular.StoryInfo info,
    SessionShell sessionShell,
    modular.StoryController controller,
  }) {
    return TestStory()..info = info;
  }

  @override
  modular.SessionShellContext get context => mockSessionShellContext;

  @override
  modular.StoryProvider get storyProvider => mockStoryProvider;

  @override
  modular.PuppetMaster get puppetMaster => mockPuppetMaster;

  @override
  modular.StoryControllerProxy newStoryController() {
    final mockCtrl = MockAsyncProxyController<modular.StoryController>();
    when(mockStoryController.ctrl).thenReturn(mockCtrl);
    return mockStoryController;
  }

  @override
  void watch(
    modular.StoryProvider storyProvider,
    modular.SessionShellContext context,
  ) {}

  @override
  modular.StoryWatcherBinding watchStory(
      modular.StoryController storyController,
      modular.StoryWatcher storyWatcher) {
    return modular.StoryWatcherBinding();
  }
}

class TestStory implements Story {
  @override
  ChildViewConnection childViewConnection;

  @override
  bool focused;

  @override
  modular.StoryState state;

  @override
  modular.StoryVisibilityState visibilityState;

  @override
  void delete() {}

  @override
  void focus() {}

  @override
  String get id => info.id;

  @override
  modular.StoryInfo info;

  @override
  void stop() {}

  @override
  void onModuleAdded(modular.ModuleData moduleData) {}

  @override
  void onModuleFocused(List<String> modulePath) {}
}

// Mock classes.
class MockStartupContext extends Mock implements StartupContext {}

class MockOutgoing extends Mock implements Outgoing {}

class MockIncomping extends Mock implements Incoming {}

class MockSessionShellContext extends Mock
    implements modular.SessionShellContext {}

class MockStoryProvider extends Mock implements modular.StoryProvider {}

class MockPuppetMaster extends Mock implements modular.PuppetMaster {}

class MockStoryController extends Mock implements modular.StoryControllerProxy {
}

class MockAsyncProxyController<T> extends Mock
    implements AsyncProxyController<T> {}

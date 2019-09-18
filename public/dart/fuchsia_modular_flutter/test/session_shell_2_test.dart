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
import 'package:fuchsia_modular_flutter/src/session_shell/internal/_session_shell_2_impl.dart';

// This is a copy of session_shell_test for SessionShell2.
// TODO(MF-481) Remove once StoryInfo transitioned to table
void main() {
  test('Create SessionShell2', () {
    expect(
        SessionShell2(
            startupContext: MockStartupContext(),
            onStoryStarted: ({
              modular.StoryInfo2 info,
              SessionShell2 sessionShell,
              modular.StoryController controller,
            }) {
              return TestStory2()..info = info;
            }),
        isNotNull);
  });

  test('Start SessionShell2', () {
    final mockStartupContext = MockStartupContext();
    final mockOutgoingImpl = MockOutgoing();
    when(mockStartupContext.outgoing).thenReturn(mockOutgoingImpl);

    TestSessionShell2(startupContext: mockStartupContext).start();

    verify(mockOutgoingImpl.addPublicService(
        any, modular.SessionShell.$serviceName));
    verify(mockOutgoingImpl.addPublicService(
        any, modular.SessionShellPresentationProvider.$serviceName));
  });

  test('Story started', () {
    String startedStoryId;
    final sessionShell = TestSessionShell2(onStoryStarted: ({
      modular.StoryInfo2 info,
      SessionShell2 sessionShell,
      modular.StoryController controller,
    }) {
      startedStoryId = info.id;
      return TestStory2()..info = info;
    })
      ..onChange2(
        modular.StoryInfo2(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      );
    expect(startedStoryId, 'foo');
    verify(sessionShell.mockStoryController.requestStart());
  });

  test('Story deleted', () {
    String deletedStoryId;
    TestSessionShell2(onStoryDeleted: (story) {
      deletedStoryId = story.id;
    })
      ..onChange2(
        modular.StoryInfo2(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      )
      ..deleteStory('foo');
    expect(deletedStoryId, 'foo');
  });

  test('Story changed', () {
    Story2 changedStory;
    TestSessionShell2(onStoryChanged: (story) {
      changedStory = story;
    })
      ..onChange2(
        modular.StoryInfo2(id: 'foo', lastFocusTime: 0),
        modular.StoryState.stopped,
        modular.StoryVisibilityState.default$,
      )
      ..onChange2(
        modular.StoryInfo2(id: 'foo', lastFocusTime: 0),
        modular.StoryState.running,
        modular.StoryVisibilityState.default$,
      );
    expect(changedStory.id, 'foo');
    expect(changedStory.state, modular.StoryState.running);
  });

  test('Story focused', () {
    Story2 changedStory;
    TestSessionShell2(onStoryChanged: (story) {
      changedStory = story;
    })
      ..onChange2(
        modular.StoryInfo2(id: 'foo', lastFocusTime: 0),
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

class TestSessionShell2 extends SessionShell2Impl {
  MockSessionShellContext mockSessionShellContext = MockSessionShellContext();
  MockStoryProvider mockStoryProvider = MockStoryProvider();
  MockPuppetMaster mockPuppetMaster = MockPuppetMaster();
  MockStoryController mockStoryController = MockStoryController();

  TestSessionShell2({
    StartupContext startupContext,
    Story2Factory onStoryStarted = _onStoryStarted,
    Story2Callback onStoryChanged,
    Story2Callback onStoryDeleted,
  }) : super(
          startupContext: startupContext ?? MockStartupContext(),
          onStoryStarted: onStoryStarted,
          onStoryDeleted: onStoryDeleted,
          onStoryChanged: onStoryChanged,
        );

  static Story2 _onStoryStarted({
    modular.StoryInfo2 info,
    SessionShell2 sessionShell,
    modular.StoryController controller,
  }) {
    return TestStory2()..info = info;
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

class TestStory2 implements Story2 {
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
  modular.StoryInfo2 info;

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

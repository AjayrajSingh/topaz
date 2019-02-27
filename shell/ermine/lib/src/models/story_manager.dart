// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:fidl/fidl.dart' show InterfaceHandle, InterfaceRequest;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart';
import 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart' show ViewOwner;
import 'package:fidl_fuchsia_modular/fidl_async.dart'
    show
        FocusControllerProxy,
        FocusProviderProxy,
        FocusRequestWatcher,
        PuppetMasterProxy,
        SessionShell,
        SessionShellBinding,
        SessionShellContext,
        StoryControllerProxy,
        StoryInfo,
        StoryProviderProxy,
        StoryProviderWatcher,
        StoryState,
        StoryVisibilityState,
        ViewIdentifier;
import 'package:fuchsia_services/services.dart' show StartupContext;
import 'package:zircon/zircon.dart';

import 'story_model.dart';

/// Manages the visual state of all stories.
class StoryManager extends ChangeNotifier {
  // Holds the map of [StoryModel] indexed by storyId.
  final _storyMap = <String, StoryModel>{};

  // Holds the list of story ids.
  final _storyIds = <String>[];

  // Holds the list of stories that were stopped (minimized).
  final _minimizedStories = <String>{};

  /// Returns the list of stories that are visible (not minimized).
  Iterable<StoryModel> get stories =>
      _storyMap.values.where((story) => story.isVisible);

  /// Returns the index of the story that is currently focused. Returns -1
  /// if no story has focus.
  int get focusedStoryIndex =>
      focusedStoryId != null ? _storyIds.indexOf(focusedStoryId) : -1;

  /// Holds the id of the story that has focus.
  String focusedStoryId;

  final _focusProvider = FocusProviderProxy();
  final _focusController = FocusControllerProxy();
  final _storyProvider = StoryProviderProxy();
  final _sessionShellBinding = SessionShellBinding();
  final PuppetMasterProxy _puppetMaster;

  /// Constructor.
  StoryManager({SessionShellContext context, PuppetMasterProxy puppetMaster})
      : _puppetMaster = puppetMaster {
    context
      ..getFocusProvider(_focusProvider.ctrl.request())
      ..getFocusController(_focusController.ctrl.request())
      ..getStoryProvider(_storyProvider.ctrl.request());
  }

  /// Advertises this instance as [SessionShell].
  void advertise(StartupContext startupContext) {
    startupContext.outgoing.addPublicService(
        (InterfaceRequest<SessionShell> request) =>
            _sessionShellBinding.bind(_SessionShellImpl(this), request),
        SessionShell.$serviceName);
  }

  Future<void> onStoryChange(
    StoryInfo storyInfo,
    StoryState storyState,
    StoryVisibilityState storyVisibilityState,
  ) async {
    if (_storyMap.containsKey(storyInfo.id)) {
      // Story may be stopping if StoryController.stop was called. Minimize it.
      if (storyState == StoryState.stopping) {
        _storyMap[storyInfo.id].stop();
      } else if (storyState == StoryState.running) {
        // Story visibility state is changing.
        _storyMap[storyInfo.id].fullscreen =
            storyVisibilityState == StoryVisibilityState.immersive;
      }
    } else {
      final storyController = StoryControllerProxy();
      await _storyProvider.getController(
        storyInfo.id,
        storyController.ctrl.request(),
      );

      _storyIds.add(storyInfo.id);
      _storyMap[storyInfo.id] = StoryModel(
        storyInfo: storyInfo,
        storyController: storyController,
        onStopped: () => _onStopped(storyInfo.id),
        onDelete: () => _onDelete(storyInfo.id),
        visualState: storyVisibilityState == StoryVisibilityState.immersive
            ? StoryVisualState.maximized
            : StoryVisualState.normal,
      )..start();

      setFocus(storyInfo.id);

      notifyListeners();
    }
  }

  Future<void> onStoryDelete(String storyId) async {
    if (_storyMap.containsKey(storyId)) {
      int index = _storyIds.indexOf(storyId);
      _storyMap[storyId].dispose();
      _storyIds.remove(storyId);
      _storyMap.remove(storyId);

      // Set focus to previous story if present.
      if (index > 0) {
        setFocus(_storyIds[index - 1]);
      } else {
        focusedStoryId = null;
        notifyListeners();
      }
    }
  }

  Future<void> onStoryFocusRequest(String storyId) async {
    if (_storyIds.contains(storyId)) {
      focusedStoryId = storyId;
    } else {
      focusedStoryId = null;
    }
    await _focusController.set(storyId);
    notifyListeners();
  }

  /// Called when the user swipes to another story.
  void onChangeFocus(int index) {
    // Stories are displayed from second screen onwards, first is empty.
    if (index > 0) {
      focusedStoryId = _storyIds[index - 1];
      _focusController.set(focusedStoryId);
    }
  }

  /// Requests focus to be set on the story.
  void setFocus(String storyId) {
    _focusProvider.request(storyId);
  }

  void _onDelete(String storyId) {
    _puppetMaster.deleteStory(storyId);
    // Remove from screen immediately.
    onStoryDelete(storyId);
  }

  void _onStopped(String storyId) {
    _minimizedStories.add(storyId);
    notifyListeners();
  }

  Future<void> attachView(
      ViewIdentifier viewId, ImportToken viewHolderToken) async {
    if (_storyMap.containsKey(viewId.storyId)) {
      _storyMap[viewId.storyId].attachView(viewHolderToken);
    }
  }

  // SessionShell
  Future<void> detachView(ViewIdentifier viewId) async {
    await onStoryDelete(viewId.storyId);
  }
}

class StoryProviderWatcherImpl extends StoryProviderWatcher {
  final StoryManager _storyManager;

  StoryProviderWatcherImpl(this._storyManager);

  @override
  Future<void> onChange(StoryInfo storyInfo, StoryState storyState,
      StoryVisibilityState storyVisibilityState) async {
    return _storyManager.onStoryChange(
        storyInfo, storyState, storyVisibilityState);
  }

  @override
  Future<void> onDelete(String storyId) async {
    return _storyManager.onStoryDelete(storyId);
  }
}

class FocusRequestWatcherImpl extends FocusRequestWatcher {
  final StoryManager _storyManager;

  FocusRequestWatcherImpl(this._storyManager);

  @override
  Future<void> onFocusRequest(String storyId) {
    return _storyManager.onStoryFocusRequest(storyId);
  }
}

class _SessionShellImpl extends SessionShell {
  final StoryManager _storyManager;

  _SessionShellImpl(this._storyManager);

  @override
  Future<void> attachView(
      ViewIdentifier viewId, InterfaceHandle<ViewOwner> viewOwner) async {
    return attachView2(viewId,
        ImportToken(value: EventPair(viewOwner.passChannel().passHandle())));
  }

  @override
  // ignore: override_on_non_overriding_method
  Future<void> attachView2(
      ViewIdentifier viewId, ImportToken viewHolderToken) async {
    return _storyManager.attachView(viewId, viewHolderToken);
  }

  @override
  Future<void> detachView(ViewIdentifier viewId) async {
    return _storyManager.detachView(viewId);
  }
}

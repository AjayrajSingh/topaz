// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;

/// Extends [modular.StoryProviderWatcher]. Notifies the session shell when a
/// story's state changes or a story is deleted.
class StoryProviderWatcherImpl extends modular.StoryProviderWatcher {
  final void Function(
    modular.StoryInfo,
    modular.StoryState,
    modular.StoryVisibilityState,
  ) _onChangeCallback;
  final void Function(String) _onDeleteCallback;

  /// Constructor.
  StoryProviderWatcherImpl(this._onChangeCallback, this._onDeleteCallback);

  @override
  Future<void> onChange(
    modular.StoryInfo storyInfo,
    modular.StoryState storyState,
    modular.StoryVisibilityState storyVisibilityState,
  ) async {
    _onChangeCallback?.call(storyInfo, storyState, storyVisibilityState);
  }

  @override
  Future<void> onDelete(String storyId) async {
    _onDeleteCallback?.call(storyId);
  }
}

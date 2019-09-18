// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;

/// Extends [modular.StoryWatcher]. Notifies session shell when modules are
/// added or receive focus.
class StoryWatcherImpl extends modular.StoryWatcher {
  final void Function(modular.ModuleData moduleData) _onModuleAddedCallback;
  final void Function(List<String> modulePath) _onModuleFocusedCallback;

  /// Constructor.
  StoryWatcherImpl(this._onModuleAddedCallback, this._onModuleFocusedCallback);

  @override
  Future<void> onModuleAdded(modular.ModuleData moduleData) async {
    _onModuleAddedCallback?.call(moduleData);
  }

  @override
  Future<void> onModuleFocused(List<String> modulePath) async {
    _onModuleFocusedCallback?.call(modulePath);
  }

  @override
  Future<void> onStateChange(modular.StoryState newState) async {}
}

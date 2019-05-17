// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;

/// Extends [modular.FocusRequestWatcher]. This class passes the request to
/// set focus on a story to the session shell.
class FocusRequestWatcherImpl extends modular.FocusRequestWatcher {
  final void Function(String) _onFocusRequestCallback;

  /// Constructor.
  FocusRequestWatcherImpl(this._onFocusRequestCallback);

  @override
  Future<void> onFocusRequest(String storyId) async {
    _onFocusRequestCallback?.call(storyId);
  }
}

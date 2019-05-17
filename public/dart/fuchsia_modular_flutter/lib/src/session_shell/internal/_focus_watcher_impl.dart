// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;

/// Extends [modular.FocusWatcher]. Notifies session shell when focus switches
/// to another story.
class FocusWatcherImpl extends modular.FocusWatcher {
  final void Function(modular.FocusInfo) _onFocusChangeCallback;

  /// Constructor.
  FocusWatcherImpl(this._onFocusChangeCallback);

  @override
  Future<void> onFocusChange(modular.FocusInfo focusInfo) async {
    _onFocusChangeCallback?.call(focusInfo);
  }
}

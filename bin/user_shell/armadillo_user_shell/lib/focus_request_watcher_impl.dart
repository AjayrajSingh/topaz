// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';

/// Called when we receive a request to focus on [storyId];
typedef OnFocusRequest = void Function(String storyId);

/// Listens for requests to change the currently focused story.
class FocusRequestWatcherImpl extends FocusRequestWatcher {
  /// Called when we receive a request to focus on a story.
  final OnFocusRequest _onFocusRequest;

  /// Constructor.
  FocusRequestWatcherImpl({OnFocusRequest onFocusRequest})
      : _onFocusRequest = onFocusRequest;

  @override
  void onFocusRequest(String storyId) {
    log.info('Received request to focus story: $storyId');
    _onFocusRequest(storyId);
  }
}

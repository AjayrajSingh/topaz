// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library dart_mozart;

import 'dart:zircon' show Handle;

// Should be set to a |mozart::NativesDelegate*| by the embedder.
@pragma("vm:entry-point")
int _context;

@pragma("vm:entry-point")
Handle _viewContainer;

class ScenicStartupInfo {
  static Handle takeViewContainer() {
    final Handle handle = _viewContainer;
    _viewContainer = null;
    return handle;
  }
}

class Scenic {
  static void offerServiceProvider(Handle handle, List<String> services) {
    _offerServiceProvider(_context, handle, services);
  }

  static void _offerServiceProvider(int context, Handle handle,
      List<String> services) native 'Scenic_offerServiceProvider';
}

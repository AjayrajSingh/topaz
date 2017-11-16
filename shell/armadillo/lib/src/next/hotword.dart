// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Signature of callbacks for hotword detection.
typedef void HotwordCallback();

/// Listens for a hotword.
abstract class Hotword {
  final Set<HotwordCallback> _listeners = new Set<HotwordCallback>();

  /// [listener] will be notified when the hotword is spoken.
  void addListener(HotwordCallback listener) {
    _listeners.add(listener);
  }

  /// Starts listening for a hotword.
  void start();

  /// Stops listening for a hotword.
  void stop();

  /// Fires all hotword callbacks.
  void onHotword() {
    for (final HotwordCallback listener in _listeners) {
      listener();
    }
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.story.fidl/link.fidl.dart';

/// Called when [LinkWatcher.notify] is called.
typedef void LinkWatcherNotifyCallback(String data);

/// Implements a [LinkWatcher] for receiving notifications from a [Link]
/// instance.
class LinkWatcherImpl extends LinkWatcher {
  /// Called when [LinkWatcher.notify] is called.
  final LinkWatcherNotifyCallback onNotify;

  /// Creates a new instance of [LinkWatcherImpl].
  LinkWatcherImpl({this.onNotify});

  @override
  void notify(String data) {
    onNotify?.call(data);
  }
}

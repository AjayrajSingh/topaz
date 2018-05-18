// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_modular/fidl.dart';
import 'package:meta/meta.dart';

/// Handler for when [LinkWatcher#notify] is called by the framework.
typedef LinkWatcherNotifyCallback = void Function(String data);

/// Implements [LinkWatcher] for receiving update notifications from a [Link].
class LinkWatcherImpl extends LinkWatcher {
  /// Called when [LinkWatcher.notify] is called.
  final LinkWatcherNotifyCallback onNotify;

  /// Creates a new instance of [LinkWatcherImpl].
  LinkWatcherImpl({
    @required this.onNotify,
  }) : assert(onNotify != null);

  @override
  void notify(String data) {
    onNotify(data);
  }
}

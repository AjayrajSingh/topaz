// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

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
  void notify(fuchsia_mem.Buffer buffer) {
    var dataVmo = new SizedVmo(buffer.vmo.handle, buffer.size);
    var data = dataVmo.read(buffer.size);
    dataVmo.close();
    onNotify(utf8.decode(data.bytesAsUint8List()));
  }
}

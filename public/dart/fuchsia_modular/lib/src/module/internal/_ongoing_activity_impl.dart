// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fuchsia_modular;
import 'package:fuchsia_logger/logger.dart';

import '../ongoing_activity.dart';

/// A concrete implementation of the [OngoingActivity] class.
class OngoingActivityImpl implements OngoingActivity {
  final fuchsia_modular.OngoingActivityProxy _proxy;

  bool _hasCalledDone = false;

  /// The default constructor. The [_proxy] will remain open to indicate
  /// to the framework that the activity is still ongoing.
  OngoingActivityImpl(this._proxy);

  @override
  void done() {
    // note: we check the variable instead of checking if the proxy has closed
    // because it is a developer error to call done twice and we can let them
    // know what they did wrong. However, if the proxy closes because something
    // happened in the framework we do not want to throw an exception.
    if (_hasCalledDone) {
      throw Exception(
          'It is an error to call OngoingActivity.done more than once. '
          'An ongoing activity can only be used one time. If you need to start '
          'a new activity use the methods on Module to do so.');
    }

    _hasCalledDone = true;

    if (_proxy.ctrl.isClosed != false) {
      _proxy.ctrl.close();
    } else {
      log.warning(
          'Attempting to call OngoingActivity.done on an already closed proxy');
    }
  }
}

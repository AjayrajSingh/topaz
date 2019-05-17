// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:fuchsia_logger/logger.dart';

class StoryVisualStateWatcherImpl extends fidl_modular.StoryVisualStateWatcher {
  @override
  Future<void> onVisualStateChange(
      fidl_modular.StoryVisualState visualState) async {
    // TODO: implement if needed.
    log.warning('Got visual state: $visualState');
  }
}

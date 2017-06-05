// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:lib.widgets/modular.dart';

/// The [ModuleModel] for the video player.
class VideoModuleModel extends ModuleModel {
  bool _isPlaying = false;

  /// Returns whether the video is playing
  bool get isPlaying => _isPlaying;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    notifyListeners();
  }

  @override
  void onStop() {
    super.onStop();
  }

  /// Toggles the play icon to a pause icon, or vice versa
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
  }
}

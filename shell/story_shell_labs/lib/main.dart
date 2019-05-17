// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_services/services.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:story_shell_labs_lib/layout/deja_layout.dart';

import 'src/story_shell_impl.dart';
import 'src/widgets/story_widget.dart';

void main() {
  setupLogger(name: 'StoryShellLabs');
  log.info('Starting up');

  final _layoutManager =
      DejaLayout(removeSurface: (e) => log.info('removeSurface $e'));

  final _storyShell = StoryShellImpl(layoutManager: _layoutManager);

  StartupContext.fromStartupInfo()
      .outgoing
      .addPublicService(_storyShell.bind, fidl_modular.StoryShell.$serviceName);

  runApp(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: StoryWidget(presenter: _layoutManager.presenter),
      ),
    ),
  );
}

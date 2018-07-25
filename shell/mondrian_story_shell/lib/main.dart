// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show window;

import 'package:fidl/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'models/inset_manager.dart';
import 'models/layout_model.dart';
import 'models/surface/surface_graph.dart';
import 'story_shell_impl.dart';
import 'widgets/mondrian.dart';

/// This is used for keeping the reference around.
// ignore: unused_element
StoryShellImpl _storyShellImpl;

/// Entry point.
void main() {
  setupLogger(name: 'Mondrian');
  trace('starting');
  log.info('Started');

  LayoutModel layoutModel = LayoutModel();
  InsetManager insetManager = InsetManager();

  final surfaceGraph = SurfaceGraph();
  surfaceGraph.addListener(() {
    insetManager.onSurfacesChanged(surfaces: surfaceGraph.size);
  });

  void onWindowMetricsChanged() {
    trace(
      'Mondrian: onWindowMetricsChanged '
          '${new MediaQueryData.fromWindow(window).size.width},'
          '${new MediaQueryData.fromWindow(window).size.height}',
    );
  }

  // Note: This implementation only supports one StoryShell at a time.
  // Initialize the one Flutter application we support
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: WindowMediaQuery(
        onWindowMetricsChanged: onWindowMetricsChanged,
        child: ScopedModel<LayoutModel>(
          model: layoutModel,
          child: ScopedModel<InsetManager>(
            model: insetManager,
            child: Mondrian(surfaceGraph: surfaceGraph),
          ),
        ),
      ),
    ),
  );

  _storyShellImpl = new StoryShellImpl(surfaceGraph);

  StartupContext.fromStartupInfo().outgoingServices
    ..addServiceForName(
      (InterfaceRequest<StoryShell> request) {
        trace('story shell request');
        log.fine('Received binding request for StoryShell');
        _storyShellImpl.bindStoryShell(request);
      },
      StoryShell.$serviceName,
    )
    ..addServiceForName(
      (InterfaceRequest<Lifecycle> request) {
        trace('lifecycle request');
        log.fine('Received binding request for Lifecycle');
        _storyShellImpl.bindLifecycle(request);
      },
      Lifecycle.$serviceName,
    );
  trace('started');
}

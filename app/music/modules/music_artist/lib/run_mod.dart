// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

/// Begins rendering a default UI for the given module while waiting for
/// any work that needs to be done asynchronously before rendering the actual
/// module content. If the module fails to load a default failure widget
/// will be rendered in its place
///
/// Authors can, optional, provide their own widget which will be displayed
/// during the loading state.
///
/// When you are ready to render your module complete the Completer with the
/// widget that you wish to render.
///
///   Completer<Widget> moduleViewReady = runModuleScaffoldAsync();
///   doAsyncWork().then(moduleViewReady.complete(widget), onError: moduleViewReady.completeError);
Completer<Widget> runModuleScaffoldAsync({
  Widget loadingWidget,
}) {
  WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized()
    ..attachRootWidget(loadingWidget ?? const _LoadingWidget())
    ..scheduleWarmUpFrame();

  Completer<Widget> completer = new Completer<Widget>();

  completer.future.then(binding.attachRootWidget, onError: (_) {
    binding.attachRootWidget(const _FailureWidget());
  });

  return completer;
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: Colors.blue,
    );
  }
}

class _FailureWidget extends StatelessWidget {
  const _FailureWidget({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: Colors.red,
    );
  }
}

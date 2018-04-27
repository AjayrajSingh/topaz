// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'widgets/mod_failure_widget.dart';
import 'widgets/mod_loading_widget.dart';

_ModuleRunner _runner;

/// [runMod] is a method which aims to simplify the process of bootstrapping
/// a module. The method is a wrapper around the flutter [runApp] method but
/// allows the developer to defer displaying the widget tree and display
/// a loading Widget in its place until the Widget tree is ready to render.
/// If no loading Widget is provided a default one will be provided by the
/// system. If a Module fails to load the [runMod] will display the error
/// to the user in a way that is consistent amonst all modules.
///
/// The [runMod] method will call the start method on the singleton
/// ModuleDriver instance. Note: this functionality is dependent on the
/// ModuleDriver being implemented as a singleton and is being
/// tracked in MS-1507.
///
/// [runMod] can be run in a synchronous manner by supplying a Widget
/// immediately like the following:
///
///   void main() {
///     runMod({
///       child: new MyWidget(),
///     });
///   }
///
/// Or, [runMod] can be run asynchronously by providing a [Future<Widget>] to
/// as the child.
///
///   void main() {
///     Future<Widget> widget = _loadRequiredConfig().then((MyConfig c) {
///       return new MyWidget(rquiredConfig: c);
///     });
///     runMod({
///       child: widget,
///     });
///   }
///
/// In this example the widget requires some configuration before it can be
/// created. The module author can pass the Future to the [runMod] method and
/// the system will draw a default loadingScreen which avoids any delay for the
/// user. When the configuration is loaded the module author can create their
/// Widget tree and the [runMod] method will replace the loading Widget with the
/// module author's Widget. If there is a failure during any part of the loading
/// process a default error screen will be shown to the user.
///
/// * [child] (required): A [Future<Widget>] or a [Widget] which will be
///   the root widget for the module.
/// * [loadingWidget] (optional): A [Widget] which, if provided, will be used
///   as the placeholder widget while waiting for the [child] widget to resolve.
///   If [child] is a [Widget] and not a [Future<Widget>] this value is ignored.
void runMod({
  @required FutureOr<Widget> child,
  Widget loadingWidget,
}) {
  if (_runner != null) {
    throw new Exception('runMod() should only be called once.');
  }

  _runner = new _ModuleRunner(
    child: child,
    loadingWidget: loadingWidget,
  )..run();
}

class _ModuleRunner {
  final FutureOr<Widget> child;
  final Widget loadingWidget;

  _ModuleRunner({
    @required this.child,
    this.loadingWidget,
  }) : assert(child != null);

  void run() {
    if (child is Future) {
      _runWithFuture(child);
    } else {
      runApp(child);
    }
  }

  void _runWithFuture(Future<Widget> widgetFuture) {
    runApp(loadingWidget ?? const ModLoadingWidget());

    widgetFuture.then(
      runApp,
      onError: (Error error) {
        runApp(const ModFailureWidget());
      },
    );
  }
}

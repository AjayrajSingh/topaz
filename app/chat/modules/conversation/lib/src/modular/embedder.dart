// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl/module_controller.fidl.dart';
import 'package:lib.module.fidl/module_state.fidl.dart';
import 'package:lib.module_resolver.fidl/daisy.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.ui.views.fidl/view_token.fidl.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

/// The actual [Embedder] class that interacts with Fuchsia APIs to resolve,
/// start, and embed a module.
class Embedder extends EmbedderModel implements ModuleWatcher {
  /// Height of the box the module will be rendered in.
  final double height;

  /// The [ModuleContext] used to grab links etc.
  final ModuleContext moduleContext;

  /// The [InterfacePair] for the [ViewOwner] used for the
  /// [ChildViewConnection].
  InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();

  /// The client for the link used by the embedded module.
  LinkProxy link = new LinkProxy();

  /// The [ChildViewConnection] of the embedded module.
  ChildViewConnection connection;

  /// A [ModuleControllerProxy].
  ModuleControllerProxy moduleControllerProxy = new ModuleControllerProxy();

  /// A [ModuleWatcherBinding] used to watch for [ModuleState] changes.
  ModuleWatcherBinding watcherBinding = new ModuleWatcherBinding();

  /// The [Embedder] constructor.
  Embedder({
    String uri,
    @required this.height,
    @required this.moduleContext,
  })
      : assert(height != null),
        super();

  @override
  bool get daisyStarted => _daisyStarted;
  bool _daisyStarted = false;

  /// Implementation for [ModuleWatcher].
  @override
  void onStateChange(ModuleState state) {
    log.info('ModuleState chaged: $state');
    switch (state) {
      case ModuleState.starting:
        status = EmbedderModelStatus.starting;
        break;
      case ModuleState.running:
        status = EmbedderModelStatus.running;
        break;
      case ModuleState.unlinked:
        status = EmbedderModelStatus.unlinked;
        break;
      case ModuleState.done:
        status = EmbedderModelStatus.done;
        break;
      case ModuleState.stopped:
        status = EmbedderModelStatus.stopped;
        break;
      case ModuleState.error:
        status = EmbedderModelStatus.error;
        break;
      default:
        log.severe('No EmbedderModelStatus mapping for $state');
    }

    notifyListeners();
  }

  /// Close down everything used to embed the module.
  void close() {
    // Stop the embedded module.
    moduleControllerProxy.stop(() {});

    link.ctrl.close();
    moduleControllerProxy.ctrl.close();
    watcherBinding.close();
  }

  /// Starts a Daisy.
  Future<Null> startDaisy({
    @required Daisy daisy,
    @required String name,
  }) async {
    if (daisyStarted) {
      return;
    }
    _daisyStarted = true;

    status = EmbedderModelStatus.resolving;
    notifyListeners();

    log..info('Starting Daisy: $daisy')..info('=> name: $name');

    moduleContext.startDaisy(
      name, // module name
      daisy,
      name, // link name
      null, // outgoingServices
      null, // incomingServices
      moduleControllerProxy.ctrl.request(),
      viewOwnerPair.passRequest(),
    );

    connection = new ChildViewConnection(viewOwnerPair.passHandle());

    moduleControllerProxy.watch(watcherBinding.wrap(this));
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    // show spinner while resolving.
    if (status != EmbedderModelStatus.running) {
      child = new Container(
        width: 32.0,
        height: 32.0,
        child: new FuchsiaSpinner(),
      );
    } else {
      child = new ChildView(connection: connection);
    }

    return new SizedBox(
      height: height,
      child: new Center(
        child: child,
      ),
    );
  }
}

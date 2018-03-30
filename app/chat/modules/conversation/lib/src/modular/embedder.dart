// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:fuchsia.fidl.views_v1_token/views_v1_token.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

const double _kMinHeight = 200.0;
const double _kMaxHeight = 500.0;

/// The actual [Embedder] class that interacts with Fuchsia APIs to resolve,
/// start, and embed a module.
class Embedder extends EmbedderModel implements LinkWatcher, ModuleWatcher {
  /// Height of the box the module will be rendered in.
  double _height;

  /// The [ModuleContext] used to grab links etc.
  final ModuleContext moduleContext;

  /// The [Daisy] to use when restarting the Daisy.
  Daisy daisy;

  /// The name of the embedded mod for restarting Daisy.
  String name;

  /// The client for the link used by the embedded module.
  LinkProxy link;

  /// A [LinkWatcherBinding] used to watch for [Link] changes.
  LinkWatcherBinding linkWatcherBinding;

  /// The [ChildViewConnection] of the embedded module.
  ChildViewConnection connection;

  /// A [ModuleControllerProxy].
  ModuleControllerProxy moduleController;

  /// A [ModuleWatcherBinding] used to watch for [ModuleState] changes.
  ModuleWatcherBinding watcherBinding;

  /// The [Embedder] constructor.
  Embedder({
    String uri,
    @required double height,
    @required this.moduleContext,
  })
      : assert(height != null),
        _height = height,
        super();

  @override
  bool get daisyStarted => _daisyStarted;
  bool _daisyStarted = false;

  /// Gets the desired height of this embedded mod.
  @override
  double get height => _height;

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

  @override
  void notify(String encoded) {
    Object jsonObject = json.decode(encoded);
    if (jsonObject is Map<String, Object> &&
        jsonObject['preferredHeight'] != null) {
      num h = jsonObject['preferredHeight'];
      _height = h.toDouble().clamp(_kMinHeight, _kMaxHeight);
      notifyListeners();
    }
  }

  /// Close down everything used to embed the module.
  void close() {
    // Stop the embedded module.
    moduleController?.stop(() {});

    linkWatcherBinding?.close();
    linkWatcherBinding = null;

    link?.ctrl?.close();
    link = null;

    moduleController?.ctrl?.close();
    moduleController = null;

    watcherBinding?.close();
    watcherBinding = null;

    _daisyStarted = false;
  }

  /// Restarts the Daisy from the previous startModule call.
  void restartModule() {
    assert(daisyStarted);

    close();
    startModule(daisy: daisy, name: name);
  }

  /// Starts a Daisy.
  void startModule({
    @required Daisy daisy,
    @required String name,
    Object additionalLinkData,
  }) {
    if (daisyStarted) {
      return;
    }

    // Remember the values for refreshing later.
    this.daisy = daisy;
    this.name = name;

    _daisyStarted = true;

    status = EmbedderModelStatus.resolving;
    notifyListeners();

    log..info('Starting Daisy: $daisy')..info('=> name: $name');

    moduleController = new ModuleControllerProxy();
    InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();

    moduleContext.embedModule(
      name, // module name
      daisy,
      null, // incomingServices
      moduleController.ctrl.request(),
      viewOwnerPair.passRequest(),
      (StartModuleStatus status) {
        // Handle daisy resolution here
        log.info('Start daisy status = $status');
      },
    );

    connection = new ChildViewConnection(viewOwnerPair.passHandle());

    link = new LinkProxy();
    moduleContext.getLink(name, link.ctrl.request());

    try {
      if (additionalLinkData != null) {
        link.updateObject(null, json.encode(additionalLinkData));
      }
    } on Exception catch (e, stackTrace) {
      log.warning(
        'Failed to encode the additional link data: $additionalLinkData',
        e,
        stackTrace,
      );
    }

    linkWatcherBinding = new LinkWatcherBinding();
    link.watch(linkWatcherBinding.wrap(this));

    watcherBinding = new ModuleWatcherBinding();
    moduleController.watch(watcherBinding.wrap(this));
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

    return new Center(
      child: child,
    );
  }
}

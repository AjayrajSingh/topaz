// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/app.dart';
import 'package:lib.lifecycle.dart/lifecycle.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.dart/module.dart';
import 'package:lib.story.dart/story.dart';

export 'package:lib.app.dart/app.dart' show ApplicationContext;

/// The [ModuleDriver] provides a high-level API for running a module in Dart
/// code. The name and structure of this library is based on the peridot layer's
/// [AppDriver][app-driver]. A Module has two primary events:
///
/// * initialize: managed by the internal [ModuleHost].
/// * terminate: managed by the internal [LifecycleHost].
///
/// Initialization
///
/// Module initialization is triggered by calling [start]. Once the module has
/// successfully initalized additional service clients are connected providing
/// access to The Module's Link and ModuleContext services.
///
/// Termintaion
///
/// Module termination is triggered by the system, all service hosts and clients
/// will automatically have thier underlying connections closed including any
/// added by making calls to exposed APIs (e.g. [link], [moduleContext]).
///
class ModuleDriver {
  final ApplicationContext _applicationContext =
      new ApplicationContext.fromStartupInfo();

  /// A [LinkClient] for this module's default Link. Async results for
  /// LinkClient methods will resolve once the Module has been initialized
  /// successfully. If access to more links is required use
  /// [moduleContext#getLink()].
  final LinkClient link = new LinkClient();

  /// The [ModuleContextClient] for this module. Async results for method calls
  /// will resolve once the Module has been initialized successfully.
  final ModuleContextClient moduleContext = new ModuleContextClient();

  final ModuleHost _module = new ModuleHost();
  LifecycleHost _lifecycle;

  /// Shadow async completion of [start].
  Completer<ModuleDriver> _start;

  /// Create a new [ModuleDriver].
  ///
  ///     ModuleDriver module = new ModuleDriver();
  ///
  /// Register for link updates:
  ///
  ///     module.link.watch()
  ///         .listen((Object json) => print('Link data: $json'));
  ///
  /// Start the module:
  ///
  ///     module.start();
  ///
  ModuleDriver() {
    _lifecycle = new LifecycleHost(
      onTerminate: _handleTerminate,
    );
  }

  /// Start the module and connect to dependent services on module
  /// initialization.
  Future<ModuleDriver> start({
    bool autoReady: true,
  }) async {
    log.fine('#start(...)');

    // Fail fast on subsequent (accidental) calls to #start() instead of
    // triggering deeper errors by re-binding the impl.
    if (_start != null) {
      Exception err =
          new Exception('moduleDrive.start(...) should only be called once.');

      _start.completeError(err);
      return _start.future;
    } else {
      _start = new Completer<ModuleDriver>();
    }

    try {
      await _lifecycle.addService(applicationContext: _applicationContext);
    } on Exception catch (err, stackTrace) {
      _start.completeError(err, stackTrace);
      return _start.future;
    }

    ModuleHostInitializeResult result;
    try {
      result = await _module.initialize(
        applicationContext: _applicationContext,
      );
    } on Exception catch (err, stackTrace) {
      _start.completeError(err, stackTrace);
      return _start.future;
    }

    // TODO(SO-1121): add error handling/checking.
    moduleContext.proxy.ctrl.bind(result.moduleContextHandle);

    try {
      await moduleContext.getLink(linkClient: link);
    } on Exception catch (err, stackTrace) {
      _start.completeError(err, stackTrace);
      return _start.future;
    }

    if (autoReady) {
      try {
        await moduleContext.ready();
      } on Exception catch (err, stackTrace) {
        _start.completeError(err, stackTrace);
      }
    }

    /// Return the instance of this module driver to enable simpler composition
    /// functional when chaining futures.
    _start.complete(this);

    return _start.future;
  }

  Future<Null> _handleTerminate() {
    log.info('closing service connections');

    List<Future<Null>> futures = <Future<Null>>[
      moduleContext.terminate(),
      _module.terminate(),
      _lifecycle.terminate(),
    ];

    return Future.wait(futures).then((_) {
      log.info('successfully closed all service connections');
    }, onError: (Error err, StackTrace stackTrace) {
      log.warning('failed to close all service connections');
      throw err;
    });
  }
}

/// [app-driver]: https://fuchsia.googlesource.com/peridot/+/master/public/lib/app_driver/cpp?autodive=0/

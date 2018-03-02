// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/app.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.entity.dart/entity.dart';
import 'package:lib.lifecycle.dart/lifecycle.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.dart/module.dart';
import 'package:lib.story.dart/story.dart';
import 'package:meta/meta.dart';

import 'entity_codec.dart';

export 'package:lib.story.dart/story.dart' show LinkClient;
export 'entity_codec.dart';

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
/// will automatically have their underlying connections closed including any
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

  /// Watch for Entity updates from Link with the name [key] and automatically
  /// decode values using [codec].
  Stream<T> watch<T>(String key, EntityCodec<T> codec, {bool all: false}) {
    StreamController<String> controller = new StreamController<String>(
      onListen: () => log.info('watch stream ($key): listening'),
      onPause: () => log.info('watch stream ($key): paused'),
      onResume: () => log.info('watch stream ($key): resuming'),
      onCancel: () => log.info('watch stream ($key): cancelled'),
    );

    Future<String> convert(_) async {
      // The String data will be null but signals that Link#setEntity(..) was
      // called and a new value should be retrieved.
      LinkClient link = await getLink(key);
      log.fine('getting Entity ref for "$key" via $link');
      // QUESTION: can the ref value change between updates to the same entity
      // values set by ComponentContext#createEntityWithData(...)?
      String ref = await link.getEntity();
      EntityResolverClient resolver = await getResolver();
      EntityClient entity = await resolver.resolveEntity(ref);
      List<String> types = await entity.getTypes();

      if (!types.contains(codec.type)) {
        // This exception will be caught and the pending future will be resolved
        // with this error.
        throw new EntityTypeException(codec.type);
      }

      return await entity.getData(codec.type);
    }

    // NOTE: do not use await, the controller.stream needs to be returned
    // syncronously so listeners can be attached without extra async book
    // keeping.
    getLink(key).then((LinkClient link) {
      log.info('watching link "${link.name}" for Entity updates');

      Stream<String> source = link.watch(all: all).asyncMap(convert);

      controller.addStream(source, cancelOnError: true).then((_) {
        log.info('link stream is "done"');
        controller.close();
      });
    }, onError: controller.addError).catchError(controller.addError);

    Stream<T> stream = controller.stream.transform(codec.decoder);

    return stream;
  }

  /// Create or update the Entity's value (translated per [codec]) and persist
  /// it to a Link with name [key].
  Future<String> put<T>(String key, T value, EntityCodec<T> codec) async {
    Completer<String> completer = new Completer<String>();

    try {
      ComponentContextClient componentContext = await getComponentContext();
      String ref =
          await componentContext.createEntityWithData(<TypeToDataEntry>[
        new TypeToDataEntry(type: codec.type, data: codec.encode(value)),
      ]);
      LinkClient link = await getLink(key);
      await link.setEntity(ref);
      completer.complete(ref);
    } on Exception catch (err, stackTrace) {
      completer.completeError(err, stackTrace);
    }

    return completer.future;
  }

  final Map<String, LinkClient> _links = <String, LinkClient>{};

  /// Async access to the underlying [LinkClient] with the name [name].
  Future<LinkClient> getLink(String name) async {
    assert(name != null);
    assert(name.isNotEmpty);

    Completer<LinkClient> completer = new Completer<LinkClient>();

    if (_links.containsKey(name)) {
      completer.complete(_links[name]);
    } else {
      try {
        LinkClient client = _links[name] = new LinkClient(name: name);
        await moduleContext.getLink(linkClient: client);
        completer.complete(client);
      } on Exception catch (err, stackTrace) {
        completer.completeError(err, stackTrace);
      }
    }

    return completer.future;
  }

  /// Cache for [getComponentContext].
  final Completer<ComponentContextClient> _componentContext =
      new Completer<ComponentContextClient>();

  /// Async access to the [ComponentContextClient].
  Future<ComponentContextClient> getComponentContext() async {
    if (_componentContext.isCompleted) {
      return _componentContext.future;
    }

    try {
      ComponentContextClient componentContext =
          await moduleContext.getComponentContext();
      _componentContext.complete(componentContext);
    } on Exception catch (err, stackTrace) {
      _componentContext.completeError(err, stackTrace);
    }

    return _componentContext.future;
  }

  /// Shadow cache for [getResolver].
  final Completer<EntityResolverClient> _resolver =
      new Completer<EntityResolverClient>();

  /// Async access to the [EntityResolverClient].
  Future<EntityResolverClient> getResolver() async {
    if (_resolver.isCompleted) {
      return _resolver.future;
    }

    try {
      ComponentContextClient context = await getComponentContext();
      EntityResolverClient resolver = await context.getEntityResolver();
      _resolver.complete(resolver);
    } on Exception catch (err, stackTrace) {
      _resolver.completeError(err, stackTrace);
    }

    return _resolver.future;
  }

  ///
  Future<ModuleControllerClient> startDaisy({
    @required String moduleName,
    String linkName,
    @required Daisy daisy,
    SurfaceRelation surfaceRelation: const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
      emphasis: 0.5,
    ),
  }) async {
    assert(moduleName != null && moduleName.isNotEmpty);
    assert(daisy != null);

    return moduleContext.startDaisy(
      moduleName: moduleName,
      daisy: daisy,
      surfaceRelation: surfaceRelation,
      linkName: linkName,
    );
  }

  ///
  Future<Null> embedDaisy() async {
    Completer<Null> completer = new Completer<Null>();

    log.fine('embeding daisy');

    completer
        .completeError(new StateError('TODO(): implement md.embedDaisy(...)'));

    return completer.future;
  }
}

/// [app-driver]: https://fuchsia.googlesource.com/peridot/+/master/public/lib/app_driver/cpp?autodive=0/

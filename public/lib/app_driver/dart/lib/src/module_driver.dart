// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_cobalt/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/intent_parameters.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.entity.dart/entity.dart';
import 'package:lib.intent_handler.dart/intent_handler.dart';
import 'package:lib.lifecycle.dart/lifecycle.dart';
import 'package:lib.module.dart/module.dart';
import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';
import 'package:modules_metrics_registry/modules_metrics_registry.dart' as modules_metrics_registry;

import 'service_client.dart';

export 'package:lib.component.dart/component.dart'
    show MessageQueueError, MessageSenderError;
export 'package:fidl_fuchsia_modular/fidl.dart' show Intent;
export 'package:lib.app_driver.dart/intent_parameters.dart'
    show IntentParameters;
export 'package:lib.module_resolver.dart/intent_builder.dart'
    show IntentBuilder;
export 'package:lib.module.dart/module.dart'
    show ModuleControllerClient, EmbeddedModule;
export 'package:lib.story.dart/story.dart' show LinkClient;
export 'package:lib.ui.flutter/child_view.dart'
    show ChildView, ChildViewConnection;

/// Function definition to handle [data] that is received from a message queue.
typedef OnReceiveMessage = void Function(Uint8List data, void Function() ack);

/// Function to run when the module terminates
typedef OnTerminate = void Function();

/// Function to run when the module terminates asynchronously
typedef OnTerminateAsync = Future<Null> Function();

typedef OnHandleIntent = void Function(
    String action, IntentParameters parameters);

// The following metrics id's must be registered here:
// https://cobalt-analytics.googlesource.com/config/+/master/fuchsia/modules/config.yaml
const int _cobaltFirstLinkDataMetricId = 9;
// const int _cobaltEntitySerializationMetricId = 2;
// const int _cobaltEventFrameRatesMetricId = 3;
const int _cobaltTimeToConnectAgentMetricId = 10;
// const int _cobaltModuleErrorMetricId = 5;
const int _cobaltTimeToStartModuleDriverMetricId = 6;
const int _cobaltTimeToStartNewModMetricId = 7;
const int _cobaltTimeToEmbedNewModMetricId = 8;

/// The [ModuleDriver] provides a high-level API for running a module in Dart
/// code. The name and structure of this library is based on the peridot layer's
/// [AppDriver][app-driver]. A Module has two primary events:
///
/// * initialize: managed by the constructor.
/// * terminate: managed by the internal [LifecycleHost].
///
/// Initialization
///
/// Module initialization is triggered by calling [startSync]. Once the module
/// has successfully initialized additional service clients are connected
/// providing access to The Module's Link and ModuleContext services.
///
/// Termination
///
/// Module termination is triggered by the system, all service hosts and clients
/// will automatically have their underlying connections closed including any
/// added by making calls to exposed APIs (e.g. [link], [moduleContext]).
///
class ModuleDriver {
  final StartupContext _startupContext = new StartupContext.fromStartupInfo();

  /// A [LinkClient] for this module's default Link. Async results for
  /// LinkClient methods will resolve once the Module has been initialized
  /// successfully. If access to more links is required use
  /// [moduleContext#getLink()].
  final LinkClient link = new LinkClient();

  /// Called when a new intent is received from the framework. When set the
  /// module driver will call [onHandleIntent] with the latest intent
  /// received, if such an intent is available.
  OnHandleIntent _onHandleIntent;

  /// Stores the latest intent received from the framework so it can be passed to
  /// [onHandleIntent] when it is set.
  Intent _intent;

  /// The [ModuleContextClient] for this module. Async results for method calls
  /// will resolve once the Module has been initialized successfully.
  final ModuleContextClient moduleContext = new ModuleContextClient();

  // Message queue proxies for receiving updates from the content provider
  // TODO(meiyili): update to handle creating to multiple message queues MS-1288
  MessageQueueClient _messageQueue;

  /// Message queue token completer
  final LoggerProxy _logger = new LoggerProxy();
  final DateTime _initializationTime;
  final Set<String> _firstObservationSent = new Set<String>();
  LifecycleHost _lifecycle;
  IntentHandlerImpl _intentHandler;
  String _packageName = 'modulePackageNameNotYetSet';

  /// Shadow async completion of [startSync].
  final _start = Completer<ModuleDriver>();

  /// A flag indicating if the user has called [startSync] yet.
  var _hasCalledStart = false;

  // Methods to run when the module is being torn down
  final List<OnTerminateAsync> _onTerminatesAsync = <OnTerminateAsync>[];

  /// Create a new [ModuleDriver].
  ///
  ///     ModuleDriver module = new ModuleDriver();
  ///
  /// [onTerminate] lets the caller specify a function to run in the
  /// onTerminate call.
  ///
  /// Register for link updates:
  ///
  ///     module.link.watch()
  ///         .listen((Object json) => print('Link data: $json'));
  ///
  /// Start the module:
  ///
  ///     module.startSync();
  ///
  ModuleDriver({
    // TODO(MS-1521): consider removing
    OnTerminate onTerminate,
  }) : _initializationTime = new DateTime.now() {
    if (onTerminate != null) {
      _onTerminatesAsync.add(() async {
        onTerminate();
        return null;
      });
    }
    _lifecycle = new LifecycleHost(
      onTerminate: _handleTerminate,
    );
    _intentHandler = IntentHandlerImpl(onHandleIntent: _handleIntent);

    _connectToCobalt();

    // Grab the current module's package name
    getComponentContext().then((ComponentContextClient componentContext) async {
      try {
        String packageName = await componentContext.getPackageName();
        _packageName = packageName;
      } on Exception catch (err, stackTrace) {
        log.warning(
          'Error retrieving module package name: $err\n$stackTrace',
        );
      }
    });

    // Observe time to default link
    // TODO(meiyili): remove once default link is deprecated
    link.watch().listen((String data) => _observeLinkData('default', data));
  }

  /// Sets the intent handler.
  set onHandleIntent(OnHandleIntent onHandleIntent) {
    _onHandleIntent = onHandleIntent;
    _handleIntent(_intent);
  }

  String _moduleName;

  /// Module name to use for metrics, if it is not set will use default package
  /// name for the module
  String get moduleName => _moduleName;
  set moduleName(String name) => _moduleName = name.trim();

  /// Add other methods to run on terminate
  void addOnTerminateHandler(OnTerminate onTerminate) => _onTerminatesAsync.add(
        () async {
          onTerminate();
          return null;
        },
      );

  /// Add a method to run on terminate asynchronously
  void addOnTerminateAsyncHandler(OnTerminateAsync onTerminate) =>
      _onTerminatesAsync.add(onTerminate);

  /// Deprecated use [#startSync] instead.
  ///
  /// Start the module and connect to dependent services on module
  /// initialization
  // @Deprecated('use startSync instead') can't add this because of linter
  Future<ModuleDriver> start() async {
    log.fine('#start(...)');
    startSync();
    return _start.future;
  }

  /// Start the module and connect to dependent services on module
  /// initialization.
  void startSync() {
    log.fine('#startSync()');

    // Fail fast on subsequent (accidental) calls to #start() instead of
    // triggering deeper errors by re-binding the impl.
    if (_hasCalledStart) {
      throw Exception('moduleDrive.startSync()) should only be called once.');
    }
    _hasCalledStart = true;

    _lifecycle.addService(startupContext: _startupContext);
    _intentHandler.addService(startupContext: _startupContext);
    connectToService(environmentServices, moduleContext.proxy.ctrl);
    moduleContext.getLink(linkClient: link);

    _cobaltLogElapsedTime(
      metricId: _cobaltTimeToStartModuleDriverMetricId,
      elapsedMicros:
          new DateTime.now().difference(_initializationTime).inMicroseconds,
      shouldIncludeModuleName: true,
    );

    // Still complete the future since the rest of the login in this class
    // awaiting on it.
    _start.complete(this);
  }

  /// Creates a message queue and returns a [Future] with the message queue
  /// token that should be passed to agents we want to connect to. If a
  /// message queue has already been created, it will return the token for the
  /// token for the already created queue and ignore the new [onMessage] method.
  ///
  /// [name] is the name of the message queue.
  /// [onMessage] should be supplied to handle the data from the message queue.
  // TODO(meiyili): Update to allow creating multiple message queues MS-1288
  Future<String> createMessageQueue({
    @required String name,
    @required OnReceiveMessage onMessage,
    @required MessageQueueErrorCallback onConnectionError,
  }) async {
    assert(name != null && name.isNotEmpty);
    assert(onMessage != null);
    log.fine('#createMessageQueue($name)');

    // Create a message queue that the module can pass to agents only if we
    // haven't already created one
    ComponentContextClient componentContext =
        await moduleContext.getComponentContext();
    _messageQueue = componentContext.obtainMessageQueue(
        name: name, onMessage: onMessage, onConnectionError: onConnectionError);
    return _messageQueue.getToken();
  }

  /// Connect to the service specified by [client] and implemented by the
  /// agent at [url].
  ///
  /// The [url] is required as multiple agents can implement the same
  /// service interface.
  Future<void> connectToAgentService<T>(
    String url,
    ServiceClient<T> client,
  ) async {
    await _start.future.timeout(Duration(seconds: 5));
    await connectToAgentServiceWithProxy(url, client.proxy);
  }

  /// Connect to the service specified by [proxy] and implemented by the
  /// agent at [url].
  /// DEPRECATED: please write a client for your service and use
  /// connectToAgentService
  Future<void> connectToAgentServiceWithProxy(
    String url,
    Proxy<dynamic> proxy,
  ) async {
    log.fine('#connectToAgentService(...)');
    final _initTime = new DateTime.now();
    assert(proxy.ctrl.$serviceName != null,
        'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');
    ComponentContextClient componentContext = await getComponentContext();

    ServiceProviderProxy serviceProviderProxy =
        await componentContext.connectToAgent(url);
    connectToService(serviceProviderProxy, proxy.ctrl);

    // Close all unnecessary bindings
    serviceProviderProxy.ctrl.close();

    _cobaltLogElapsedTime(
      metricId: _cobaltTimeToConnectAgentMetricId,
      elapsedMicros: new DateTime.now().difference(_initTime).inMicroseconds,
    );
  }

  /// Connect to an agent using a new-style async proxy.
  Future<void> connectToAgentServiceWithAsyncProxy(
    String url,
    AsyncProxy<dynamic> proxy,
  ) async {
    log.fine('#connectToAgentService(...)');
    final _initTime = new DateTime.now();
    assert(proxy.ctrl.$serviceName != null,
        'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');

    final serviceName = proxy.ctrl.$serviceName;
    ComponentContextClient componentContext = await getComponentContext();

    await componentContext.connectToAgent(url)
      ..connectToService(serviceName, proxy.ctrl.request().passChannel())
      // Close all unnecessary bindings
      ..ctrl.close();

    _cobaltLogElapsedTime(
      metricId: _cobaltTimeToConnectAgentMetricId,
      elapsedMicros: new DateTime.now().difference(_initTime).inMicroseconds,
    );
  }

  /// Retrieve the story id of the story this module lives in
  Future<String> getStoryId() {
    log.fine('#getStoryId(...)');
    return moduleContext.getStoryId();
  }

  Future<Null> _handleTerminate() {
    log.info('closing service connections');

    _messageQueue?.close();
    _logger.ctrl.close();

    List<Future<Null>> futures = <Future<Null>>[
      moduleContext.terminate(),
      _lifecycle.terminate(),
    ]..addAll(
        _onTerminatesAsync.map((OnTerminateAsync onTerminate) => onTerminate()),
      );

    return Future.wait(futures).then((_) {
      log.info('successfully closed all service connections');
    }, onError: (Error err, StackTrace stackTrace) {
      log.warning('failed to close all service connections');
      throw err;
    });
  }

  void _handleIntent(Intent intent) {
    log.info('Received intent from framework');
    _intent = intent;
    if (_onHandleIntent != null && intent != null) {
      _onHandleIntent(intent.action,
          IntentParameters(moduleDriver: this, parameters: intent.parameters));
    }
  }

  /// Watch for Entity updates from Link with the name [key] and automatically
  /// decode values using [codec].
  Stream<T> watch<T>(String key, EntityCodec<T> codec, {bool all = false}) {
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
      // If the link does not contain an entity, attempt to get it as json
      // before returning an error.
      if (ref == null) {
        fuchsia_mem.Buffer buffer = await link.get();
        if (buffer == null) {
          return null;
        }
        var dataVmo = new SizedVmo(buffer.vmo.handle, buffer.size);
        var data = dataVmo.read(buffer.size);
        dataVmo.close();
        return jsonDecode(utf8.decode(data.bytesAsUint8List()));
      }
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
    // synchronously so listeners can be attached without extra async book
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

  /// Watch for Entity updates from Link with the name [key] and return the
  /// raw bytes in the Link's value.
  /// decode values using [codec].
  Stream<Uint8List> watchRaw(String key, {bool all = false}) {
    StreamController<Uint8List> controller = new StreamController<Uint8List>(
      onListen: () => log.info('watchRaw stream ($key): listening'),
      onPause: () => log.info('watchRaw stream ($key): paused'),
      onResume: () => log.info('watchRaw stream ($key): resuming'),
      onCancel: () => log.info('watchRaw stream ($key): cancelled'),
    );

    Future<Uint8List> convert(_) async {
      fuchsia_mem.Buffer buffer = await link.get();
      if (buffer == null) {
        return null;
      }
      var dataVmo = new SizedVmo(buffer.vmo.handle, buffer.size);
      var data = dataVmo.read(buffer.size);
      dataVmo.close();
      return data.bytesAsUint8List();
    }

    // NOTE: do not use await, the controller.stream needs to be returned
    // synchronously so listeners can be attached without extra async book
    // keeping.
    getLink(key).then((LinkClient link) {
      log.info('watching link "${link.name}" for Entity updates');

      Stream<Uint8List> source = link.watch(all: all).asyncMap(convert);
      controller.addStream(source, cancelOnError: true).then((_) {
        log.info('link stream is "done"');
        controller.close();
      });
    }, onError: controller.addError).catchError(controller.addError);

    return controller.stream;
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

  /// Retrieve the current value stored on the Link with the name [key].
  /// The value is converted from an Entity and decoded using [codec].
  Future<T> get<T>(String key, EntityCodec<T> codec) async {
    Completer<T> completer = new Completer<T>();

    try {
      LinkClient link = await getLink(key);
      String entityRef = await link.getEntity();
      if (entityRef == null) {
        return null;
      }
      EntityResolverClient resolver = await getResolver();
      EntityClient entity = await resolver.resolveEntity(entityRef);
      List<String> types = await entity.getTypes();
      if (!types.contains(codec.type)) {
        throw new EntityTypeException(codec.type);
      }

      String data = await entity.getData(codec.type);
      completer.complete(codec.decoder.convert(data));
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
        client.watch().listen((String data) => _observeLinkData(name, data));
        completer.complete(client);
      } on Exception catch (err, stackTrace) {
        completer.completeError(err, stackTrace);
      }
    }

    return completer.future;
  }

  /// Report that this module is active even without user interaction. This
  /// is used by the story shell to allow long running modules to avoid
  /// timeout due to user inactivity.
  void active() {
    log.fine('#active(...)');
    moduleContext.active();
  }

  /// When a module calls [done] the framework will stop the module. If there
  /// are no more running modules in the story the story will be stopped.
  Future<void> done() {
    return moduleContext.done();
  }

  /// Log a cobalt metric when the link data first becomes non-null.
  void _observeLinkData(String linkName, String data) {
    if (!_firstObservationSent.contains(linkName) && data != null) {
      _firstObservationSent.add(linkName);

      int linkIndex = linkName == 'card_data' ? 0 : 1;
      _cobaltLogElapsedTime(
        metricId: _cobaltFirstLinkDataMetricId,
        enumIndex: linkIndex,
        elapsedMicros:
            new DateTime.now().difference(_initializationTime).inMicroseconds,
        shouldIncludeModuleName: true,
      );
    }
  }

  /// Cache for [getComponentContext].
  Completer<ComponentContextClient> _componentContext;

  /// Async access to the [ComponentContextClient].
  Future<ComponentContextClient> getComponentContext() async {
    if (_componentContext == null) {
      _componentContext = new Completer<ComponentContextClient>();
      try {
        _componentContext.complete(await moduleContext.getComponentContext());
      } on Exception catch (err, stackTrace) {
        _componentContext.completeError(err, stackTrace);
      }
    }

    return _componentContext.future;
  }

  /// Shadow cache for [getResolver].
  Completer<EntityResolverClient> _resolver;

  /// Async access to the [EntityResolverClient].
  Future<EntityResolverClient> getResolver() async {
    if (_resolver == null) {
      _resolver = new Completer<EntityResolverClient>();
      try {
        ComponentContextClient context = await getComponentContext();
        _resolver.complete(await context.getEntityResolver());
      } on Exception catch (err, stackTrace) {
        _resolver.completeError(err, stackTrace);
      }
    }

    return _resolver.future;
  }

  /// # Start Module
  ///
  /// Start a module and display it based on the passed in [surfaceRelation].
  ///
  /// On successful resolution the Future completes with a
  /// [ModuleControllerClient] that allows the parent module (the one calling
  /// this method) to access methods for observing and controlling the Module.
  ///
  /// Related FIDL APIs:
  ///
  /// * [ModuleContext#StartModule](https://goo.gl/9T8Gkv).
  /// * [ModuleController](https://goo.gl/ZXcYW3).
  ///
  /// TODO(MS-1714): collapse name params or clearly document their differences.
  Future<ModuleControllerClient> startModule({
    @required Intent intent,
    String name,
    String module,
    SurfaceRelation surfaceRelation = const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
      emphasis: 0.5,
    ),
  }) async {
    final _initTime = new DateTime.now();
    name ??= module;
    assert(name != null && name.isNotEmpty);
    assert(intent != null);

    if (module != null) {
      // TODO(MS-1443): remove deprecation notice once client usage has been
      // updated.
      log.warning('param "module" is deprecated, use "name" instead');
    }

    return moduleContext
        .addModuleToStory(
          module: name,
          intent: intent,
          surfaceRelation: surfaceRelation,
        )
        .whenComplete(
          () => _cobaltLogElapsedTime(
                metricId: _cobaltTimeToStartNewModMetricId,
                component: name,
                elapsedMicros:
                    new DateTime.now().difference(_initTime).inMicroseconds,
              ),
        );
  }

  /// # Embed Module
  ///
  /// Calls underlying framework APIs to start and configure a module instance
  /// for embedding within a Flutter Widget tree.
  ///
  /// On successful resolution the Future completes with an [EmbeddedModule]
  /// instance providing access to a [ChildView] Flutter Widget and a
  /// [ModuleControllerClient].
  ///
  /// Related FIDL APIs:
  ///
  /// * [ModuleContext#EmbedModule](https://goo.gl/9T8Gkv).
  /// * [ModuleController](https://goo.gl/ZXcYW3).
  ///
  Future<EmbeddedModule> embedModule({
    @required String name,
    @required Intent intent,
  }) async {
    assert(name != null && name.isNotEmpty);
    assert(intent != null);

    log.fine('resolving module ("$name") for embedding...');
    final _initTime = new DateTime.now();
    return moduleContext.embedModule(name: name, intent: intent).whenComplete(
          () => _cobaltLogElapsedTime(
                metricId: _cobaltTimeToEmbedNewModMetricId,
                component: name,
                elapsedMicros:
                    new DateTime.now().difference(_initTime).inMicroseconds,
              ),
        );
  }

  /// Made available for video module to access MediaPlayer.
  /// TODO(MS-1287): Determine whether this should be refactored
  ServiceProviderProxy get environmentServices =>
      _startupContext.environmentServices;

  /// The [LoggerProxy] for sending Cobalt metrics
  LoggerProxy get cobaltLogger => _logger;

  void _connectToCobalt() {
    LoggerFactoryProxy loggerFactory = new LoggerFactoryProxy();
    connectToService(environmentServices, loggerFactory.ctrl);

    SizedVmo configVmo =
        SizedVmo.fromUint8List(base64.decode(modules_metrics_registry.config));
    ProjectProfile profile = ProjectProfile(
      config: fuchsia_mem.Buffer(vmo: configVmo, size: configVmo.size),
      releaseStage: ReleaseStage.ga,
    );

    loggerFactory.createLogger(
      profile,
      _logger.ctrl.request(),
      (Status s) {
        if (s != Status.ok) {
          log.warning('Failed to create Logger. Cobalt config is invalid.');
        }
      },
    );
    loggerFactory.ctrl.close();
  }

  /// Helper method to emit cobalt metrics.
  void _cobaltLogElapsedTime({
    int metricId,
    int elapsedMicros,
    int enumIndex = 0,
    String component = '',
    shouldIncludeModuleName = false,
  }) {
    String componentString;
    if (shouldIncludeModuleName) {
      componentString =
          moduleName == null || moduleName.isEmpty ? _packageName : moduleName;
    } else {
      componentString = component;
    }

    _logger.logElapsedTime(
      metricId,
      enumIndex,
      componentString,
      elapsedMicros,
      (Status status) {
        if (status != Status.ok) {
          log.warning('Failed to observe frame Cobalt metric '
              '$metricId: $status.');
        }
      },
    );
  }
}

/// [app-driver]: https://fuchsia.googlesource.com/peridot/+/master/public/lib/app_driver/cpp?autodive=0/

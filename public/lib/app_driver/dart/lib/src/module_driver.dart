// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_cobalt/fidl.dart';
import 'package:fidl_component/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.entity.dart/entity.dart';
import 'package:lib.lifecycle.dart/lifecycle.dart';
import 'package:lib.module.dart/module.dart';
import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:meta/meta.dart';

import 'service_client.dart';

export 'package:fidl_modular/fidl.dart' show Intent;
export 'package:lib.module_resolver.dart/intent_builder.dart'
    show IntentBuilder;
export 'package:lib.module.dart/module.dart'
    show ModuleControllerClient, EmbeddedModule;
export 'package:lib.story.dart/story.dart' show LinkClient;
export 'package:lib.ui.flutter/child_view.dart'
    show ChildView, ChildViewConnection;

/// Function definition to handle [data] that is received from a message queue.
typedef void OnReceiveMessage(String data, void ack());

/// Function to run when the module terminates
typedef void OnTerminate();

/// Function to run when the module terminates asynchronously
typedef Future<Null> OnTerminateAsync();

const int _kCobaltProjectId = 104;
const int _kFirstLinkDataMetricId = 1;

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

  // Message queue proxies for receiving updates from the content provider
  // TODO(meiyili): update to handle creating to multiple message queues MS-1288
  MessageQueueProxy _messageQueue;
  MessageReceiverImpl _messageQueueReceiver;

  /// Message queue token completer
  final Completer<String> _tokenCompleter = new Completer<String>();

  final ModuleHost _module = new ModuleHost();
  final CobaltEncoderProxy _encoder = new CobaltEncoderProxy();
  final DateTime _initializationTime;
  final Set<String> _firstObservationSent = new Set<String>();
  LifecycleHost _lifecycle;
  String _packageName = 'modulePackageNameNotYetSet';

  /// Shadow async completion of [start].
  Completer<ModuleDriver> _start;

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
  ///     module.start();
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

    // Connect to Cobalt
    CobaltEncoderFactoryProxy encoderFactory = new CobaltEncoderFactoryProxy();
    connectToService(
      environmentServices,
      encoderFactory.ctrl,
    );
    encoderFactory.getEncoder(_kCobaltProjectId, _encoder.ctrl.request());
    encoderFactory.ctrl.close();

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

  /// Start the module and connect to dependent services on module
  /// initialization.
  Future<ModuleDriver> start() async {
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

    /// Return the instance of this module driver to enable simpler composition
    /// functional when chaining futures.
    _start.complete(this);

    return _start.future;
  }

  /// Creates a message queue and returns a [Future] with the message queue
  /// token that should be passed to agents we want to connect to. If a
  /// message queue has already been created, it will return the token for the
  /// token for the already created queue and ignore the new [onReceive] method.
  ///
  /// [name] is the name of the message queue.
  /// [onReceive] should be supplied to handle the data from the message queue.
  // TODO(meiyili): Update to allow creating multiple message queues MS-1288
  Future<String> createMessageQueue({
    @required String name,
    @required OnReceiveMessage onReceive,
  }) async {
    assert(name != null && name.isNotEmpty);
    assert(onReceive != null);
    log.fine('#createMessageQueue(...)');

    // Create a message queue that the module can pass to agents only if we
    // haven't already created one
    if (!_tokenCompleter.isCompleted) {
      ComponentContextClient componentContext =
          await moduleContext.getComponentContext();
      _messageQueue = await componentContext.obtainMessageQueue(name)
        ..getToken(_tokenCompleter.complete);

      // TODO(jasoncampbell): create MessageReceiverHost around the impl MS-1301
      _messageQueueReceiver = new MessageReceiverImpl(
        messageQueue: _messageQueue,
        onReceiveMessage: onReceive,
      );
    }

    return _tokenCompleter.future;
  }

  /// Connect to the service specified by [client] and implemented by the
  /// agent at [url].
  ///
  /// The [url] is required as multiple agents can implement the same
  /// service interface.
  Future<Null> connectToAgentService<T>(
    String url,
    ServiceClient<T> client,
  ) async {
    await _start.future;
    await connectToAgentServiceWithProxy(url, client.proxy);
  }

  /// Connect to the service specified by [proxy] and implemented by the
  /// agent at [url].
  /// DEPRECATED: please write a client for your service and use
  /// connectToAgentService
  Future<Null> connectToAgentServiceWithProxy(
    String url,
    Proxy<dynamic> proxy,
  ) async {
    log.fine('#connectToAgentService(...)');
    ComponentContextClient componentContext = await getComponentContext();

    ServiceProviderProxy serviceProviderProxy =
        await componentContext.connectToAgent(url);
    connectToService(serviceProviderProxy, proxy.ctrl);

    // Close all unnecessary bindings
    serviceProviderProxy.ctrl.close();
  }

  /// Retrieve the story id of the story this module lives in
  Future<String> getStoryId() {
    log.fine('#getStoryId(...)');
    return moduleContext.getStoryId();
  }

  Future<Null> _handleTerminate() {
    log.info('closing service connections');

    _messageQueueReceiver?.close();
    _messageQueue?.ctrl?.close();
    _encoder.ctrl.close();

    List<Future<Null>> futures = <Future<Null>>[
      moduleContext.terminate(),
      _module.terminate(),
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
      if (ref == null) {
        return null;
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
        client.watch().listen((String data) => _observeLinkData(name, data));
        completer.complete(client);
      } on Exception catch (err, stackTrace) {
        completer.completeError(err, stackTrace);
      }
    }

    return completer.future;
  }

  /// Log a cobalt metric when the link data first becomes non-null.
  void _observeLinkData(String linkName, String data) {
    if (!_firstObservationSent.contains(linkName) && data != null) {
      _firstObservationSent.add(linkName);

      _encoder.addMultipartObservation(
        _kFirstLinkDataMetricId,
        <ObservationValue>[
          new ObservationValue(
            name: 'module_name',
            value: new Value.withStringValue(
              moduleName == null || moduleName.isEmpty
                  ? _packageName
                  : moduleName,
            ),
            encodingId: 1,
          ),
          new ObservationValue(
            name: 'link_name',
            value: new Value.withStringValue(linkName),
            encodingId: 1,
          ),
          new ObservationValue(
            name: 'elapsed_millis',
            value: new Value.withIntValue(
              new DateTime.now().difference(_initializationTime).inMilliseconds,
            ),
            encodingId: 1,
          )
        ],
        (Status status) {
          if (status != Status.ok) {
            log.warning(
              'Failed to observe frame rate metric '
                  '$_kCobaltProjectId, '
                  '$_kFirstLinkDataMetricId: $status. ',
            );
          }
        },
      );
    }
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
  Future<ModuleControllerClient> startModule({
    @required String module,
    @required Intent intent,
    SurfaceRelation surfaceRelation: const SurfaceRelation(
      arrangement: SurfaceArrangement.copresent,
      dependency: SurfaceDependency.dependent,
      emphasis: 0.5,
    ),
  }) async {
    assert(module != null && module.isNotEmpty);
    assert(intent != null);

    return moduleContext.startModule(
      module: module,
      intent: intent,
      surfaceRelation: surfaceRelation,
    );
  }

  /// # Embed Module
  ///
  /// Calls underlying framework APIs to start and configure a module instance
  /// for embedding within a Flutter Widget tree.
  ///
  /// On successful resolution the Future completes with an [EmbeddedModule]
  /// instance provding access to a [ChildView] Flutter Widget and a
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
  }) {
    assert(name != null && name.isNotEmpty);
    assert(intent != null);

    log.fine('resolving module ("$name") for embedding...');

    return moduleContext.embedModule(name: name, intent: intent);
  }

  /// Made available for video module to access MediaPlayer.
  /// TODO(MS-1287): Determine whether this should be refactored
  ServiceProviderProxy get environmentServices =>
      _applicationContext.environmentServices;

  /// The [CobaltEncoderProxy] for sending Cobalt metrics
  CobaltEncoderProxy get cobaltEncoder => _encoder;
}

/// [app-driver]: https://fuchsia.googlesource.com/peridot/+/master/public/lib/app_driver/cpp?autodive=0/

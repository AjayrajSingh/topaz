// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_mem/fidl_async.dart' as mem;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:fidl_fuchsia_ui_gfx/fidl_async.dart' as gfx;
import 'package:fidl_fuchsia_ui_viewsv1token/fidl_async.dart' as views;
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart' as zx;

import '../../entity/entity.dart';
import '../../entity/internal/_entity_impl.dart';
import '../embedded_module.dart';
import '../intent.dart';
import '../intent_handler.dart';
import '../module.dart';
import '../module_state_exception.dart';
import '../ongoing_activity.dart';
import '_intent_handler_impl.dart';
import '_module_context.dart';
import '_ongoing_activity_impl.dart';

/// A concrete implementation of the [Module] interface. This class
/// is not intended to be used directly by authors but instead should
/// be used by the [Module] factory constructor.
class ModuleImpl implements Module {
  /// Holds a reference to the already registered intent handler
  IntentHandler _intentHandler;

  /// The intent handler host which will proxy intents to the registered
  /// intent handler
  // ignore: unused_field
  IntentHandlerImpl _intentHandlerImpl;

  /// Returns the [fidl.ModuleContext] for the running module.
  /// This variable should not be used directly. Use the
  /// [getContext()] method instead
  modular.ModuleContext _moduleContext;

  /// The default constructor for this instance.
  ///
  /// the [moduleContext] is an optional parameter that
  /// can be supplied to override the default module context.
  /// This is mainly useful in testing scenarios.
  ModuleImpl({
    @required IntentHandlerImpl intentHandlerImpl,
    Lifecycle lifecycle,
    modular.ModuleContext moduleContext,
  })  : _moduleContext = moduleContext,
        assert(intentHandlerImpl != null) {
    (lifecycle ??= Lifecycle()).addTerminateListener(_terminate);
    _intentHandlerImpl = intentHandlerImpl
      ..onHandleIntent = _proxyIntentToIntentHandler;
  }

  @override
  Future<modular.ModuleController> addModuleToStory({
    @required String name,
    @required modular.Intent intent,
    modular.SurfaceRelation surfaceRelation = const modular.SurfaceRelation(
      arrangement: modular.SurfaceArrangement.copresent,
      dependency: modular.SurfaceDependency.dependent,
      emphasis: 0.5,
    ),
  }) async {
    if (name == null || name.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'addModuleToStory should be called with a valid name');
    }
    if (intent == null) {
      throw ArgumentError.notNull('intent');
    }

    final moduleControllerProxy = modular.ModuleControllerProxy();

    modular.StartModuleStatus status = await _getContext().addModuleToStory(
        name, intent, moduleControllerProxy.ctrl.request(), surfaceRelation);

    _validateStartModuleStatus(status, name, intent);

    return moduleControllerProxy;
  }

  @override
  Future<Entity> createEntity({
    @required String type,
    @required Uint8List initialData,
  }) async {
    ArgumentError.checkNotNull(type, 'type');
    ArgumentError.checkNotNull(initialData, 'initialData');

    if (type.isEmpty) {
      throw ArgumentError.value(type, 'type cannot be an empty string');
    }

    final context = _getContext();

    // need to create the proxy and write data immediately so other modules
    // can extract values
    final proxy = modular.EntityProxy();
    final vmo = zx.SizedVmo.fromUint8List(initialData);
    final buffer = mem.Buffer(vmo: vmo, size: initialData.length);
    final ref = await context.createEntity(type, buffer, proxy.ctrl.request());

    // use the ref value to determine if creation was successful
    if (ref == null || ref.isEmpty) {
      throw Exception('Module.createEntity creation failed because'
          ' the framework was unable to create the entity.');
    }

    return EntityImpl(type: type, proxyFactory: () => proxy);
  }

  @override
  Future<EmbeddedModule> embedModule({
    @required String name,
    @required modular.Intent intent,
  }) async {
    return embedModuleNew(name: name, intent: intent);
  }

  @override
  Future<EmbeddedModule> embedModuleNew({
    @required String name,
    @required modular.Intent intent,
  }) async {
    if (name == null || name.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'embedModuleNew should be called with a valid name');
    }
    if (intent == null) {
      throw ArgumentError.notNull('intent');
    }

    final moduleController = modular.ModuleControllerProxy();
    final viewOwner = new InterfacePair<views.ViewOwner>();
    final status = await _getContext().embedModule(
        name, intent, moduleController.ctrl.request(), viewOwner.passRequest());

    _validateStartModuleStatus(status, name, intent);

    return EmbeddedModule(
        moduleController: moduleController,
        viewHolderToken: gfx.ImportToken(
            value: zx.EventPair(
                viewOwner.passHandle().passChannel().passHandle())));
  }

  @override
  void registerIntentHandler(IntentHandler intentHandler) {
    if (_intentHandler != null) {
      throw ModuleStateException(
          'Intent handler registration failed because a handler is already '
          'registered.');
    }

    _intentHandler = intentHandler;
  }

  @override
  void removeSelfFromStory() {
    _getContext().removeSelfFromStory();
  }

  @override
  void requestFocus() {
    _getContext().requestFocus();
  }

  @override
  OngoingActivity startOngoingActivity(modular.OngoingActivityType type) {
    final proxy = modular.OngoingActivityProxy();
    _getContext().startOngoingActivity(type, proxy.ctrl.request());

    return OngoingActivityImpl(proxy);
  }

  modular.ModuleContext _getContext() => _moduleContext ??= getModuleContext();

  void _proxyIntentToIntentHandler(Intent intent) {
    if (_intentHandler == null) {
      throw ModuleStateException(
          'Module received an intent but no intent handler was registered to '
          'receive it. If you do not intend to handle intents but you still '
          'need to use the module functionality register a NoopIntentHandler '
          'to explicitly declare that you will not handle the intent.');
    }
    _intentHandler.handleIntent(intent);
  }

  // any necessary cleanup should be done in this method.
  Future<void> _terminate() async {
    _intentHandler = null;
  }

  void _validateStartModuleStatus(
      modular.StartModuleStatus status, String name, modular.Intent intent) {
    switch (status) {
      case modular.StartModuleStatus.success:
        break;
      case modular.StartModuleStatus.noModulesFound:
        throw ModuleResolutionException(
            'no modules found for intent [$intent]');
        break;
      default:
        throw ModuleStateException(
            'unknown start module status [$status] for intent [$intent]');
    }
  }
}

/// When Module resolution fails.
class ModuleResolutionException implements Exception {
  /// Information about the failure.
  final String message;

  /// Create a new [ModuleResolutionException].
  ModuleResolutionException(this.message);
}

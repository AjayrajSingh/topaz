// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia/services.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import '_intent_handler_impl.dart';
import 'intent.dart';
import 'intent_handler.dart';
import 'module.dart';
import 'module_state_exception.dart';

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

  // Module context proxy that is lazily instantiated in [_getContext]
  fidl.ModuleContextProxy _moduleContextProxy;

  /// The default constructor for this instance.
  ModuleImpl({
    @required IntentHandlerImpl intentHandlerImpl,
    Lifecycle lifecycle,
    fidl.ModuleContextProxy moduleContextProxy,
  }) : assert(intentHandlerImpl != null) {
    (lifecycle ??= Lifecycle()).addTerminateListener(_terminate);
    _moduleContextProxy ??= moduleContextProxy;
    _intentHandlerImpl = intentHandlerImpl
      ..onHandleIntent = _proxyIntentToIntentHandler;
  }

  @override
  void registerIntentHandler(IntentHandler intentHandler) {
    if (_intentHandler != null) {
      throw ModuleStateException(
          'Intent handler registration failed because a handler is already registered.');
    }

    _intentHandler = intentHandler;
  }

  @override
  Future<fidl.ModuleController> addModuleToStory({
    String name,
    fidl.Intent intent,
    fidl.SurfaceRelation surfaceRelation = const fidl.SurfaceRelation(
      arrangement: fidl.SurfaceArrangement.copresent,
      dependency: fidl.SurfaceDependency.dependent,
      emphasis: 0.5,
    ),
  }) async {
    final moduleControllerProxy = fidl.ModuleControllerProxy();

    fidl.StartModuleStatus status = await _getContext().addModuleToStory(
        name, intent, moduleControllerProxy.ctrl.request(), surfaceRelation);

    switch (status) {
      case fidl.StartModuleStatus.success:
        break;
      case fidl.StartModuleStatus.noModulesFound:
        throw ModuleResolutionException(
            'no modules found for intent [$intent]');
        break;
      default:
        throw ModuleStateException(
            'unknown start module status [$status] for intent [$intent]');
    }

    return moduleControllerProxy;
  }

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

  /// Returns the [fidl.ModuleContext] for the running module.
  ///
  /// It is safe to call this method multiple times without opening multiple
  /// connections.
  ///
  /// This method is intentionally private until an actual need arises to expose
  /// it publicly.
  fidl.ModuleContext _getContext() {
    if (_moduleContextProxy != null) {
      return _moduleContextProxy;
    }

    _moduleContextProxy = fidl.ModuleContextProxy();
    connectToEnvironmentService(_moduleContextProxy);
    return _moduleContextProxy;
  }

  // any necessary cleanup should be done in this method.
  Future<void> _terminate() async {
    _intentHandler = null;
  }
}

/// When Module resolution fails.
class ModuleResolutionException implements Exception {
  /// Information about the failure.
  final String message;

  /// Create a new [ModuleResolutionException].
  ModuleResolutionException(this.message);
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:meta/meta.dart';

import 'intent_handler.dart';
import 'internal/_intent_handler_impl.dart';
import 'internal/_module_impl.dart';

/// The [Module] class provides a mechanism for module authors
/// to interact with the underlying framework. The main responsibilities
/// of the [Module] class are to implement the intent handler
/// interface and the lifecycle interface.
abstract class Module {
  static Module _module;

  /// returns a shared instance of this.
  factory Module() {
    return _module ??= ModuleImpl(
      intentHandlerImpl:
          IntentHandlerImpl(startupContext: StartupContext.fromStartupInfo()),
    );
  }

  /// Registers the [intentHandler] with this.
  ///
  /// This method must be called in the main function of the module
  /// so the framework has a chance to connect the intent handler.
  ///
  /// ```
  /// void main() {
  ///   Module()
  ///     ..registerIntentHandler(MyHandler());
  /// }
  /// ```
  void registerIntentHandler(IntentHandler intentHandler);

  /// Starts a new Module instance and adds it to the story. The Module to
  /// execute is identified by the contents of [intent] and the Module instance
  /// is given a [name] in the scope of the starting Module instance. The view
  /// for the Module is given to the StoryShell for display.
  ///
  /// Providing a [surfaceRelation] advises the StoryShell on how to layout
  /// surfaces that the new module creates. If [surfaceRelation] is `null` then
  /// a default relation is used. Note, [surfaceRelation] is an optional
  /// parameter so a default value will be provided:
  /// ```
  /// fidl.SurfaceRelation surfaceRelation = const fidl.SurfaceRelation(
  ///    arrangement: fidl.SurfaceArrangement.copresent,
  ///    dependency: fidl.SurfaceDependency.dependent,
  ///    emphasis: 0.5,
  /// )
  ///```
  ///
  /// If this method is called again with the same [name] by the same Module
  /// instance, but with different arguments, a new module will be started and
  /// replace the existing one (the ModuleController of the existing module will
  /// be closed). If the [intent] is resolved to the same module, the module
  /// will get the intent.
  ///
  /// A [fidl.ModuleController] is returned to the caller to control the start
  /// Module instance. Closing this connection doesn't affect its Module
  /// instance; it just relinquishes the ability of the caller to control the
  /// Module instance.
  Future<fidl.ModuleController> addModuleToStory({
    @required String name,
    @required fidl.Intent intent,
    fidl.SurfaceRelation surfaceRelation,
  });
}

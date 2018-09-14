// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/services.dart';

import '_intent_handler_host.dart';
import '_module_impl.dart';
import 'intent_handler.dart';

/// The [Module] class provides a mechanism for module authors
/// to interact with the underlying framework. The main responsibilities
/// of the [Module] class are to implement the intent handler
/// interface and the lifecycle interface.
abstract class Module {
  static Module _module;

  /// returns a shared instance of this.
  factory Module() {
    return _module ??= ModuleImpl(
      intentHandlerHost:
          IntentHandlerHost(startupContext: StartupContext.fromStartupInfo()),
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
}

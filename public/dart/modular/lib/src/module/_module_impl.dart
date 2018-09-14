// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '_intent_handler_host.dart';
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
  //ignore: unused_field
  IntentHandlerHost _intentHandlerHost;

  /// The default constructor for this instance.
  ModuleImpl({@required IntentHandlerHost intentHandlerHost})
      : assert(intentHandlerHost != null) {
    _intentHandlerHost = intentHandlerHost
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

  void _proxyIntentToIntentHandler(String name, Intent intent) {
    if (_intentHandler == null) {
      throw ModuleStateException(
          'Module received an intent but no intent handler was registered to '
          'receive it. If you do not intend to handle intents but you still '
          'need to use the module functionality register a NoopIntentHandler '
          'to explicitly declare that you will not handle the intent.');
    }
    _intentHandler.handleIntent(name, intent);
  }
}

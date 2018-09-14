// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';

import 'intent_handler.dart';

/// A concrete implementation of the [fidl.IntentHandler] interface.
/// This class not intended to be used directly by authors but instead should
/// be used by classes which need to expose the [fidl.IntentHandler] interface
/// and forward intents to handlers. See the Module class for an example of
/// this in practice.
class IntentHandlerHost extends fidl.IntentHandler {
  final _intentHandlerBinding = fidl.IntentHandlerBinding();

  /// A function which is invoked when the host receives a [handleIntent] call.
  void Function(String name, Intent intent) onHandleIntent;

  /// The constructor for the [IntentHandlerHost].
  /// The [startupContext] is an optional parameter that will
  /// default to using [StartupContext.fromStartupInfo] if not present.
  IntentHandlerHost({StartupContext startupContext}) {
    _exposeService(startupContext ?? StartupContext.fromStartupInfo());
  }

  void _exposeService(StartupContext startupContext) {
    startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.IntentHandler> request) =>
          _intentHandlerBinding.bind(this, request),
      fidl.IntentHandler.$serviceName,
    );
  }

  @override
  Future<Null> handleIntent(fidl.Intent intent) async {
    if (onHandleIntent == null) {
      return null;
    }

    // TODO: translate the incoming intent into a signature that is
    // not fidl specific.
    onHandleIntent('', Intent());

    // Need to return null here to make the compiler happy. This should
    // go away when the generated fidl code returns Future<void>.
    return null;
  }
}

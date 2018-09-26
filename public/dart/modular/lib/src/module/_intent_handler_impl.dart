// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';

import 'intent.dart';

/// A concrete implementation of the [fidl.IntentHandler] interface.
/// This class not intended to be used directly by authors but instead should
/// be used by classes which need to expose the [fidl.IntentHandler] interface
/// and forward intents to handlers. See the Module class for an example of
/// this in practice.
///
/// Note: This class must be exposed to the framework before the first iteration
/// of the event loop. Therefore, it must be initialized by the time the Module
/// is initialize.
class IntentHandlerImpl extends fidl.IntentHandler {
  final _intentHandlerBinding = fidl.IntentHandlerBinding();

  /// A function which is invoked when the host receives a [handleIntent] call.
  void Function(Intent intent) onHandleIntent;

  /// The constructor for the [IntentHandlerImpl].
  /// The [startupContext] is an optional parameter that will
  /// default to using [StartupContext.fromStartupInfo] if not present.
  IntentHandlerImpl({StartupContext startupContext}) {
    _exposeService(startupContext ?? StartupContext.fromStartupInfo());
  }

  // Note: this method needs to run before the first iteration of
  // the event loop or the framework will not bind to it.
  void _exposeService(StartupContext startupContext) {
    startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.IntentHandler> request) =>
          _intentHandlerBinding.bind(this, request),
      fidl.IntentHandler.$serviceName,
    );
  }

  @override
  Future<void> handleIntent(fidl.Intent intent) async {
    if (onHandleIntent == null) {
      return null;
    }

    // convert to the non-fidl intent.
    onHandleIntent(Intent(
      action: intent.action ?? '',
      parameters:
          _getIntentParametersFromFidlIntentParameters(intent.parameters),
    ));
  }

  List<IntentParameter> _getIntentParametersFromFidlIntentParameters(
          List<fidl.IntentParameter> parameters) =>
      parameters
          .map(_intentParameterFromFidlIntentParameter)
          .toList(growable: false);

  IntentParameter _intentParameterFromFidlIntentParameter(
      fidl.IntentParameter parameter) {
    switch (parameter.data.tag) {
      case fidl.IntentParameterDataTag.entityReference:
        return EntityIntentParameter(
          name: parameter.name,
          entityReference: parameter.data.entityReference,
        );
      default:
        throw Exception(
            'IntentParameter with type ${parameter.data.tag} is not supported at this time');
    }
  }
}

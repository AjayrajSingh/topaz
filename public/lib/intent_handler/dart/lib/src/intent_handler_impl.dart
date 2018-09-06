// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart' as fidl;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

/// Callback for [IntentHandler#handleIntent].
typedef HandleIntentCallback = void Function(fidl.Intent intent);

/// Impl for [fidl.IntentHandler].
class IntentHandlerImpl extends fidl.IntentHandler {
  /// Callback for when the system calls [handleIntent].
  final HandleIntentCallback onHandleIntent;

  final _intentHandlerBinding = fidl.IntentHandlerBinding();

  /// Creates an [fidl.IntentHandler] which calls [onHandleIntent] when a
  /// new intent is received from the framework.
  IntentHandlerImpl({
    @required this.onHandleIntent,
  }) : assert(onHandleIntent != null) {
    _intentHandlerBinding
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  @override
  void handleIntent(fidl.Intent intent) {
    onHandleIntent(intent);
  }

  /// Adds an [fidl.IntentHandler] service to the outgoing services of [startupContext].
  void addService({
    @required StartupContext startupContext,
  }) {
    assert(startupContext != null);

    log.fine('starting intent handler');

    if (_intentHandlerBinding.isBound) {
      log.warning('Intent handler has already been bound.');
      return;
    }

    startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.IntentHandler> request) {
        try {
          _intentHandlerBinding.bind(this, request);
        } on Exception catch (err, stackTrace) {
          log.warning('Intent handler connection died', err, stackTrace);
        }
      },
      fidl.IntentHandler.$serviceName,
    );
  }

  void _handleConnectionError() {
    log.fine(
        'Intent handler connection died: ${_intentHandlerBinding.isBound}');
  }

  void _handleBind() {
    log.fine('Intent handler bound');
  }

  void _handleUnbind() {
    log.fine('Intent handler unbound');
  }

  void _handleClose() {
    log.fine('Intent handler closed');
  }
}

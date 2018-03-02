// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.logging/logging.dart';
// This import should not need the "._module_controller" in the path, see
// DNO-201
import 'package:lib.module.fidl._module_controller/module_controller.fidl.dart'
    as fidl;

/// Client wrapper for [fidl.ModuleController].
class ModuleControllerClient {
  /// The underlying [fidl.ModuleControllerProxy] used to send client requests
  /// to the [fidl.ModuleController] service.
  final fidl.ModuleControllerProxy proxy = new fidl.ModuleControllerProxy();

  /// Constructor.
  ModuleControllerClient() {
    proxy.ctrl
      ..onBind = _handleBind
      ..onClose = _handleClose
      ..onConnectionError = _handleConnectionError
      ..onUnbind = _handleUnbind;
  }

  void _handleBind() {
    log.fine('proxy ready');
  }

  void _handleConnectionError() {
    Exception err = new Exception('binding connection failed');
    throw err;
  }

  void _handleClose() {
    log.fine('proxy closed, terminating link clients');
  }

  void _handleUnbind() {
    log.fine('proxy unbound');
  }

  /// Closes the underlying proxy connection, should be called as a response to
  /// Lifecycle::terminate (see https://goo.gl/MmZ2dc).
  Future<Null> terminate() async {
    log.fine('terminate called');
    proxy.ctrl.close();
  }
}

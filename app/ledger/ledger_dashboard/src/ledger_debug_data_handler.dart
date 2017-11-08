// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:peridot.bin.ledger.fidl/debug.fidl.dart';

import 'data_handler.dart';

class LedgerDebugDataHandler extends DataHandler {
  @override
  String get name => 'ledger_debug';

  // connection to LedgerRepositoryDebug
  LedgerRepositoryDebugProxy _ledgerRepositoryDebug;

  @override
  void init(ApplicationContext appContext, SendWebSocketMessage sender) {
    _ledgerRepositoryDebug = new LedgerRepositoryDebugProxy();
    connectToService(
        appContext.environmentServices, _ledgerRepositoryDebug.ctrl);
    assert(_ledgerRepositoryDebug.ctrl.isBound);
  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    _ledgerRepositoryDebug.getInt((int value) => callbackFunc(request, value));
    return true;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {}

  void callbackFunc(HttpRequest request, int value) {
    request.response.write(value);
    request.response.close();
  }
}

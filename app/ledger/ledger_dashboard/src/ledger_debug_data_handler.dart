// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:io';

import 'package:lib.app.dart/app.dart';

import 'data_handler.dart';

class LedgerDebugDataHandler extends DataHandler {
  @override
  String get name => "ledger_debug";

  @override
  void init(ApplicationContext appContext, SendWebSocketMessage sender) {

  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {

  }

}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:peridot.bin.ledger.fidl/debug.fidl.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart' as ledger_fidl;

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
    List<String> requestArr = requestString.split('/');
    Map<String, String> queryParam = request.requestedUri.queryParameters;
    if (requestArr[1] == 'instances_list') {
      _ledgerRepositoryDebug.getInstancesList((List<String> listOfInstances) =>
          sendInstancesList(request, listOfInstances));
      return true;
    } else if (requestArr[1] == 'pages_list') {
      LedgerDebugProxy ledgerDebug = new LedgerDebugProxy();
      ledgerDebug.ctrl.onConnectionError = () {
        print('Connection Error on Ledger Debug: ${ledgerDebug.hashCode}');
      };

      _ledgerRepositoryDebug.getLedgerDebug(
          UTF8.encode(queryParam['instance']), ledgerDebug.ctrl.request(),
          (ledger_fidl.Status s) {
        if (s != ledger_fidl.Status.ok) {
          print('[ERROR] LEDGER name failed to bind.');
        }
      });
      ledgerDebug.getPagesList(
          (List<List<int>> listOfPages) => sendList(request, listOfPages));
      return true;
    }

    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {}

  void sendInstancesList(HttpRequest request, List<String> listOfInstances) {
    request.response.write(JSON.encode(listOfInstances));
    request.response.close();
  }

  void sendList(HttpRequest request, List<List<int>> listOfEncod) {
    request.response.write(JSON.encode(listOfEncod));
    request.response.close();
  }
}

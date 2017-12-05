// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:lib.app.dart/app.dart';
import 'package:peridot.bin.ledger.fidl/debug.fidl.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart' as ledger_fidl;

import 'data_handler.dart';

/// WebSocketHolder is a container for the socket attached with its proxies;
/// ledgerDebug, pageDebug, etc.
class WebSocketHolder {
  /// Provides the socket connection attached to this container.
  WebSocket _webSocket;

  /// Provides a proxy for ledgerDebug attached to this socket connection.
  LedgerDebugProxy ledgerDebug;

  /// The class constructor initializes _webSocket.
  WebSocketHolder(this._webSocket);

  /// Sends messages over _webSocket.
  void add(String msg) {
    _webSocket.add(msg);
  }

  /// Handles the termination of _webSocket.
  void close() {
    ledgerDebug = null;
  }
}

class LedgerDebugDataHandler extends DataHandler {
  @override
  String get name => 'ledger_debug';

  // connection to LedgerRepositoryDebug
  LedgerRepositoryDebugProxy _ledgerRepositoryDebug;

  List<WebSocketHolder> _activeWebsockets;

  @override
  void init(ApplicationContext appContext) {
    _ledgerRepositoryDebug = new LedgerRepositoryDebugProxy();
    connectToService(
        appContext.environmentServices, _ledgerRepositoryDebug.ctrl);
    assert(_ledgerRepositoryDebug.ctrl.isBound);
    _activeWebsockets = <WebSocketHolder>[];
  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {
    WebSocketHolder socketHolder = new WebSocketHolder(socket);
    _activeWebsockets.add(socketHolder);
    socket.listen(
        // ignore: avoid_annotating_with_dynamic
        ((dynamic event) => handleWebsocketRequest(socketHolder, event)),
        onDone: (() => handleWebsocketClose(socketHolder)));
    //Send the ledger instances list
    _ledgerRepositoryDebug.getInstancesList((List<List<int>> listOfInstances) =>
        sendList(socketHolder, 'instances_list', listOfInstances));
  }

  void sendList(WebSocketHolder socketHolder, String listName,
      List<List<int>> listOfEncod) {
    String message = JSON.encode(<String, dynamic>{listName: listOfEncod});
    socketHolder.add(message);
  }

  void handleWebsocketRequest(
      WebSocketHolder socketHolder,
      // ignore: avoid_annotating_with_dynamic
      dynamic event) {
    dynamic request = JSON.decode(event);
    if (request is Map<String, List<int>>) {
      if (request['instance_name'] != null) {
        LedgerDebugProxy ledgerDebug = new LedgerDebugProxy();
        ledgerDebug.ctrl.onConnectionError = () {
          print('Connection Error on Ledger Debug: ${ledgerDebug.hashCode}');
        };
        _ledgerRepositoryDebug.getLedgerDebug(
            request['instance_name'], ledgerDebug.ctrl.request(),
            (ledger_fidl.Status s) {
          if (s != ledger_fidl.Status.ok) {
            print('[ERROR] LEDGER name failed to bind.');
          }
        });
        ledgerDebug.getPagesList((List<List<int>> listOfPages) =>
            sendList(socketHolder, 'pages_list', listOfPages));
        socketHolder.ledgerDebug = ledgerDebug;
      }
    }
  }

  void handleWebsocketClose(WebSocketHolder socketHolder) {
    _activeWebsockets.remove(socketHolder);
    socketHolder.close();
  }
}

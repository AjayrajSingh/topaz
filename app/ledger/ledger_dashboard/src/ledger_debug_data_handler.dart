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

  /// Provides a proxy for pageDebug attached to this socket connection.
  PageDebugProxy pageDebug;

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
    _ledgerRepositoryDebug.ctrl.onConnectionError = () {
      print(
          'Connection Error on Ledger Repository Debug: ${_ledgerRepositoryDebug.hashCode}');
    };
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

  void handleWebsocketRequest(
      WebSocketHolder socketHolder,
      // ignore: avoid_annotating_with_dynamic
      dynamic event) {
    dynamic request = JSON.decode(event);
    if (request['instance_name'] != null)
      handlePagesRequest(socketHolder, request);
    else if (request['page_name'] != null)
      handleCommitsRequest(socketHolder, request);
  }

  void handlePagesRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
    if (request['instance_name'] is List<int>) {
      LedgerDebugProxy ledgerDebug = new LedgerDebugProxy();
      ledgerDebug.ctrl.onConnectionError = () {
        print('Connection Error on Ledger Debug: ${ledgerDebug.hashCode}');
      };
      _ledgerRepositoryDebug
          .getLedgerDebug(request['instance_name'], ledgerDebug.ctrl.request(),
              (ledger_fidl.Status s) {
        if (s != ledger_fidl.Status.ok) {
          print('[ERROR] LEDGER name failed to bind.');
        }
      });
      ledgerDebug.getPagesList((List<List<int>> listOfPages) =>
          sendList(socketHolder, 'pages_list', listOfPages));
      socketHolder.ledgerDebug = ledgerDebug;
    } else {
      print('[ERROR] LEDGER instance name type is wrong.');
    }
  }

  void handleCommitsRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
    if (request['page_name'] is List<int>) {
      if (socketHolder.ledgerDebug != null) {
        PageDebugProxy pageDebug = new PageDebugProxy();
        pageDebug.ctrl.onConnectionError = () {
          print('Connection Error on Page Debug: ${pageDebug.hashCode}');
        };
        socketHolder.ledgerDebug
            .getPageDebug(request['page_name'], pageDebug.ctrl.request(),
                (ledger_fidl.Status s) {
          if (s != ledger_fidl.Status.ok) {
            print('[ERROR] PageDebug failed to bind.');
          }
        });
        pageDebug.getHeadCommitsIds(
            (ledger_fidl.Status s, List<List<int>> listOfCommits) =>
                sendList(socketHolder, 'commits_list', listOfCommits, s));
        socketHolder.pageDebug = pageDebug;
      }
    } else {
      print('[ERROR] LEDGER page name type is wrong.');
      return;
    }
  }

  void sendList(WebSocketHolder socketHolder, String listName,
      List<List<int>> listOfEncod,
      [ledger_fidl.Status s = ledger_fidl.Status.ok]) {
    if (s == ledger_fidl.Status.ok) {
      String message = JSON.encode(<String, dynamic>{listName: listOfEncod});
      socketHolder.add(message);
    }
  }

  void handleWebsocketClose(WebSocketHolder socketHolder) {
    _activeWebsockets.remove(socketHolder);
    socketHolder.close();
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_ledger_internal/fidl.dart';
import 'package:fidl_ledger/fidl.dart' as ledger_fidl;

import 'data_handler.dart';

/// WebSocketHolder is a container for the socket attached with its proxies;
/// ledgerDebug, pageDebug, etc.
class WebSocketHolder {
  /// Provides the socket connection attached to this container.
  WebSocket _webSocket;

  /// Provides a proxy for ledgerDebug attached to this socket connection.
  LedgerDebugProxy _ledgerDebug;

  /// Provides a proxy for pageDebug attached to this socket connection.
  PageDebugProxy _pageDebug;

  /// Provides a proxy for pageSnapshot attached to this socket connection.
  ledger_fidl.PageSnapshotProxy _pageSnapshot;

  /// The class constructor initializes _webSocket.
  WebSocketHolder(this._webSocket);

  LedgerDebugProxy get ledgerDebug => _ledgerDebug;

  set ledgerDebug(LedgerDebugProxy proxy) {
    closeLedgerDebug();
    closePageDebug();
    closePageSnapshot();
    _ledgerDebug = proxy;
  }

  PageDebugProxy get pageDebug => _pageDebug;

  set pageDebug(PageDebugProxy proxy) {
    closePageDebug();
    closePageSnapshot();
    _pageDebug = proxy;
  }

  ledger_fidl.PageSnapshotProxy get pageSnapshot => _pageSnapshot;

  set pageSnapshot(ledger_fidl.PageSnapshotProxy proxy) {
    closePageSnapshot();
    _pageSnapshot = proxy;
  }

  /// Sends messages over _webSocket.
  void add(String msg) {
    _webSocket.add(msg);
  }

  void closeLedgerDebug() {
    _ledgerDebug?.ctrl?.close();
    _ledgerDebug = null;
  }

  void closePageDebug() {
    _pageDebug?.ctrl?.close();
    _pageDebug = null;
  }

  void closePageSnapshot() {
    _pageSnapshot?.ctrl?.close();
    _pageSnapshot = null;
  }

  /// Handles the termination of _webSocket.
  void close() {
    closeLedgerDebug();
    closePageDebug();
    closePageSnapshot();
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
        ((dynamic event) => handleWebsocketRequest(socketHolder, event)),
        onDone: (() => handleWebsocketClose(socketHolder)));
    //Send the ledger instances list
    _ledgerRepositoryDebug.getInstancesList((List<List<int>> listOfInstances) =>
        sendList(socketHolder, 'instances_list', listOfInstances));
  }

  void handleWebsocketRequest(WebSocketHolder socketHolder, dynamic event) {
    dynamic request = json.decode(event);
    if (request['instance_name'] != null && isValidId(request['instance_name']))
      handlePagesRequest(socketHolder, request);
    else if (request['page_name'] != null && isValidId(request['page_name']))
      handleHeadCommitsRequest(socketHolder, request);
    else if (request['commit_id'] != null && isValidId(request['commit_id']))
      handleEntriesRequest(socketHolder, request);
    else if (request['commit_obj_id'] != null &&
        isValidId(request['commit_obj_id']))
      handleCommitObjRequest(socketHolder, request);
  }

  bool isValidId(List<int> request) {
    for (int i = 0; i < request.length; i++) {
      if (request[i] is! int) {
        return false;
      }
    }
    return true;
  }

  void handlePagesRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
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
    ledgerDebug.getPagesList((List<ledger_fidl.PageId> listOfPages) => sendList(
        socketHolder,
        'pages_list',
        listOfPages.map((ledger_fidl.PageId id) => id.id.toList())));
    socketHolder.ledgerDebug = ledgerDebug;
  }

  void handleHeadCommitsRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
    if (socketHolder.ledgerDebug != null) {
      PageDebugProxy pageDebug = new PageDebugProxy();
      pageDebug.ctrl.onConnectionError = () {
        print('Connection Error on Page Debug: ${pageDebug.hashCode}');
      };
      socketHolder.ledgerDebug?.getPageDebug(
          new ledger_fidl.PageId(
              id: new Uint8List.fromList(request['page_name'])),
          pageDebug.ctrl.request(), (ledger_fidl.Status s) {
        if (s != ledger_fidl.Status.ok) {
          print('[ERROR] PageDebug failed to bind.');
        }
      });
      pageDebug.getHeadCommitsIds(
          (ledger_fidl.Status s, List<CommitId> listOfCommits) => sendList(
              socketHolder,
              'commits_list',
              listOfCommits.map((CommitId id) => id.id.toList()),
              s));
      socketHolder.pageDebug = pageDebug;
    } else {
      print(
          '[ERROR] The corresponding Ledger instance isn\'\t bound properly.');
    }
  }

  void handleEntriesRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
    if (socketHolder.ledgerDebug != null && socketHolder.pageDebug != null) {
      ledger_fidl.PageSnapshotProxy pageSnapshot =
          new ledger_fidl.PageSnapshotProxy();
      pageSnapshot.ctrl.onConnectionError = () {
        print('Connection Error on Page Snapshot: ${pageSnapshot.hashCode}');
      };
      socketHolder.pageDebug?.getSnapshot(
          new CommitId(id: new Uint8List.fromList(request['commit_id'])),
          pageSnapshot.ctrl.request(), (ledger_fidl.Status s) {
        if (s != ledger_fidl.Status.ok) {
          print('[ERROR] PageSnapshot failed to bind.');
        }
      });
      socketHolder.pageSnapshot = pageSnapshot;
      recursiveGetEntries(socketHolder, null);
    } else {
      print(
          '[ERROR] The corresponding Ledger instance and page aren\'\t bound properly');
    }
  }

  void recursiveGetEntries(WebSocketHolder socketHolder, List<int> nextToken) {
    socketHolder.pageSnapshot?.getEntries(
        null,
        nextToken,
        (ledger_fidl.Status s, List<ledger_fidl.Entry> listOfEntries,
                List<int> nextToken) =>
            sendEntries(
                socketHolder, 'entries_list', listOfEntries, s, nextToken));
  }

  void handleCommitObjRequest(
      WebSocketHolder socketHolder, Map<String, List<int>> request) {
    if (socketHolder.ledgerDebug != null && socketHolder.pageDebug != null) {
      socketHolder.pageDebug?.getCommit(
          new CommitId(id: new Uint8List.fromList(request['commit_obj_id'])),
          (ledger_fidl.Status s, Commit commit) =>
              sendCommit(socketHolder, s, commit));
    } else {
      print(
          '[ERROR] The corresponding Ledger instance and page aren\'\t bound properly');
    }
  }

  void sendList(WebSocketHolder socketHolder, String listName,
      List<List<int>> listOfEncod,
      [ledger_fidl.Status s = ledger_fidl.Status.ok]) {
    if (s == ledger_fidl.Status.ok) {
      String message = json.encode(<String, dynamic>{listName: listOfEncod});
      socketHolder.add(message);
    }
  }

  void sendEntries(
      WebSocketHolder socketHolder,
      String listName,
      List<ledger_fidl.Entry> listOfEncod,
      ledger_fidl.Status s,
      List<int> nextToken) {
    if ((s == ledger_fidl.Status.ok) ||
        (s == ledger_fidl.Status.partialResult)) {
      List<List<Object>> entriesList = <List<Object>>[];
      for (int i = 0; i < (listOfEncod?.length ?? 0); i++) {
        bool isTruncated = listOfEncod[i].value.size > 500;
        List<Object> singleEntry = <Object>[]
          ..add(listOfEncod[i].key)
          ..add(listOfEncod[i]
              .value
              .vmo
              .read(min(500, listOfEncod[i].value.size))
              .bytesAsUint8List())
          ..add(isTruncated)
          ..add(listOfEncod[i].priority);
        entriesList.add(singleEntry);
      }
      String message = json.encode(<String, dynamic>{listName: entriesList});
      socketHolder.add(message);
      if (s == ledger_fidl.Status.partialResult) {
        recursiveGetEntries(socketHolder, nextToken);
      }
    }
  }

  void sendCommit(
      WebSocketHolder socketHolder, ledger_fidl.Status s, Commit commit) {
    if (s == ledger_fidl.Status.ok) {
      List<Object> commitObj = <Object>[]
        ..add(commit.commitId)
        ..add(commit.parentsIds)
        ..add(commit.timestamp)
        ..add(commit.generation);
      String message = json.encode(<String, dynamic>{'commit_obj': commitObj});
      socketHolder.add(message);
    }
  }

  void handleWebsocketClose(WebSocketHolder socketHolder) {
    _activeWebsockets.remove(socketHolder);
    socketHolder.close();
  }
}

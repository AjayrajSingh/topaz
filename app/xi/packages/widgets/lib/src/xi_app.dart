// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:xi_client/client.dart';

import 'home_page.dart';
import 'editor.dart';

/// Top-level Widget.
class XiApp extends StatefulWidget {
  /// The client API interface to the xi-core Fuchsia service.
  final XiClient xi;

  /// [XiApp] constructor.
  XiApp({
    Key key,
    @required this.xi,
  })
      : super(key: key) {
    assert(xi != null);
  }

  @override
  XiAppState createState() => new XiAppState();
}

/// A handler for RPC's and notifications from core, dispatching to
/// an [EditorState] object.
// TODO: dispatch to multiple editor tabs
class XiAppHandler extends XiRpcHandler {
  EditorState _editorState;

  /// Constructor
  XiAppHandler(this._editorState);

  @override
  void handleNotification(String method, dynamic params) {
    switch (method) {
      case 'update':
        Map<String, dynamic> update = params['update'];
        print('update, update=$update');
        List<Map<String, dynamic>> ops = update['ops'];
        _editorState.update(ops);
        break;
      default:
        print('notification, unknown method $method, params=$params');
    }
  }

  @override
  dynamic handleRpc(String method, dynamic params) {
    print('rpc method=$method');
    return null;
  }
}

/// State for XiApp.
class XiAppState extends State<XiApp> {
  /// Allows parent [Widget]s in either vanilla Flutter or Fuchsia to modify
  /// the [HomePage]'s [message].
  String message;
  String _tabId;
  EditorState _editorState;

  /// Route a notification to the xi core. Called by [Editor] widget.
  void sendNotification(String method, dynamic params) {
    Map<String, dynamic> innerParams = <String, dynamic>{'method': method, 'params': params, 'tab': _tabId};
    config.xi.sendNotification('edit', innerParams);
  }

  /// Connect editor state, so that notifications from the core are routed to
  /// the editor. Called by [Editor] widget.
  void connectEditor(EditorState editorState) {
    config.xi.registerHandler(new XiAppHandler(editorState));
  }

  @override
  void initState() {
    super.initState();
    config.xi.onMessage(handleMessage);
    config.xi.init().then((Null _) =>
      // Arguably the new_tab should be sent by the editor (and the editor should plumb
      // the tab id through to the connectEditor call). However, that would require holding
      // a pending queue of new_tab requests, waiting for init to complete. This is easier.
      config.xi.sendRpc('new_tab', <dynamic>[], (String id) {
        _tabId = id;
        print('id = $id');
      })
    );
  }

  /// Handle messages from xi-core.
  void handleMessage(dynamic data) {
    setState(() => message = '$data');
  }

  /// Handler passed into [XiApp] for negotiating IPC calls to the xi-core
  /// service. Currently this is unsupported for vanilla Flutter.
  void handlePingButtonPressed() {
    sendNotification('insert', <String, dynamic>{'chars': 'a'});
  }

  /// Uses a [MaterialApp] as the root of the Xi UI hierarchy.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Xi',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new HomePage(
        title: 'Xi Example Home Page',
        message: message,
        onFabPressed: handlePingButtonPressed,
      ),
    );
  }
}

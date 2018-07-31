// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:xi_client/client.dart';

import 'editor.dart';

// ignore_for_file: avoid_annotating_with_dynamic

/// Top-level Widget.
class XiApp extends StatefulWidget {
  /// The client API interface to the xi-core Fuchsia service.
  final XiClient xi;
  final bool drawDebugBackground;

  /// [XiApp] constructor.
  const XiApp({
    @required this.xi,
    this.drawDebugBackground = false,
    Key key,
  })  : assert(xi != null),
        super(key: key);

  @override
  XiAppState createState() =>
      new XiAppState(debugBackground: drawDebugBackground);
}

/// A temporary [XiHandler] that just wraps a single [EditorState] object.
// TODO: dispatch to multiple editor tabs
// TODO (crothfels) implement XiHandler on [XiAppState] and get rid of this
class XiAppHandler extends XiHandler {
  EditorState _editorState;

  /// Constructor
  XiAppHandler(this._editorState);

  @override
  void alert(String text) {
    log.warning('received alert: $text');
  }

  @override
  XiViewHandler getView(String viewId) {
    return _editorState;
  }

  @override
  List<double> measureWidths(List<Map<String, dynamic>> args) {
    return _editorState.measureWidths(args);
  }
}

class _PendingNotification {
  _PendingNotification(this.method, this.params);
  String method;
  dynamic params;
}

/// State for XiApp.
class XiAppState extends State<XiApp> {
  /// Allows parent [Widget]s in either vanilla Flutter or Fuchsia to modify
  /// the message.
  String message;

  /// If `true`, draws a watermark in the background of the editor view.
  bool debugBackground = false;
  String _viewId;
  List<_PendingNotification> _pendingReqs;

  XiAppState({@required this.debugBackground});

  /// Route a notification to the xi core. Called by [Editor] widget. If the tab
  /// has not yet initialized, notifications are queued up until it has.
  void sendNotification(String method, dynamic params) {
    if (_viewId == null) {
      _pendingReqs ??= <_PendingNotification>[];
      _pendingReqs.add(new _PendingNotification(method, params));
    } else {
      Map<String, dynamic> innerParams = <String, dynamic>{
        'method': method,
        'params': params,
        'view_id': _viewId
      };
      widget.xi.sendNotification('edit', innerParams);
    }
  }

  /// Connect editor state, so that notifications from the core are routed to
  /// the editor. Called by [Editor] widget.
  void connectEditor(EditorState editorState) {
    widget.xi.handler = new XiHandlerAdapter(XiAppHandler(editorState));
  }

  @override
  void initState() {
    super.initState();
    widget.xi.onMessage(handleMessage);

    /// ignore: void_checks
    widget.xi.init().then((Null _) {
      widget.xi.sendNotification('client_started', <String, dynamic>{});
      // Arguably new_view should be sent by the editor (and the editor should plumb
      // the view id through to the connectEditor call). However, that would require holding
      // a pending queue of new_view requests, waiting for init to complete. This is easier.
      return widget.xi
          .sendRpc('new_view', <String, dynamic>{}).then((dynamic id) {
        _viewId = id;
        log.info('setting view_id = $id');
        if (_pendingReqs != null) {
          for (_PendingNotification pending in _pendingReqs) {
            sendNotification(pending.method, pending.params);
          }
          _pendingReqs = null;
        }
      }).catchError((err) => log.warning('RPC returned error', err));
    });
  }

  /// Handle messages from xi-core.
  void handleMessage(dynamic data) {
    setState(() => message = '$data');
  }

  /// Uses a [MaterialApp] as the root of the Xi UI hierarchy.
  @override
  Widget build(BuildContext context) {
    const editor = Editor();
    return new MaterialApp(
        title: 'Xi',
        home: new Material(
            // required for the debug background to render correctly
            type: MaterialType.transparency,
            child: Container(
              constraints: new BoxConstraints.expand(),
              color: Colors.white,
              child: debugBackground ? _makeDebugBackground(editor) : editor,
            )));
  }
}

/// Creates a new widget with the editor overlayed on a watermarked background
Widget _makeDebugBackground(Widget editor) {
  return new Stack(children: <Widget>[
    Container(
        constraints: new BoxConstraints.expand(),
        child: new Center(
            child: Transform.rotate(
          angle: -math.pi / 6.0,
          child: new Text('xi editor',
              style: TextStyle(
                  fontSize: 144.0,
                  color: Colors.pink[50],
                  fontWeight: FontWeight.w800)),
        ))),
    editor,
  ]);
}

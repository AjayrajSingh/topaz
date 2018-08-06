// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:xi_client/client.dart';

import 'editor.dart';

/// Top-level Widget.
class XiApp extends StatefulWidget {
  /// The client API interface to the xi-core Fuchsia service.
  final CoreProxy coreProxy;
  final bool drawDebugBackground;

  /// [XiApp] constructor.
  const XiApp({
    @required this.coreProxy,
    this.drawDebugBackground = false,
    Key key,
  })  : assert(coreProxy != null),
        super(key: key);

  @override
  XiAppState createState() => new XiAppState();
}

/// State for XiApp.
class XiAppState extends State<XiApp> implements XiHandler {
  EditorState _editorState;

  XiAppState();

  bool _initialized = false;

  // if we get a newView request before we've init'd, we return this future
  Completer<XiViewProxy> _pendingView;

  /// Connect editor state, so that notifications from the core are routed to
  /// the editor. Called by [Editor] widget.
  Future<XiViewProxy> connectEditor(EditorState editorState) {
    log.info('connect editor');
    assert(_editorState == null);
    _editorState = editorState;
    if (!_initialized) {
      _pendingView = new Completer<XiViewProxy>();
      return _pendingView.future;
    } else {
      return widget.coreProxy
          .newView()
          .then((viewId) => widget.coreProxy.view(viewId));
    }
  }

  @override
  void initState() {
    super.initState();
    widget.coreProxy.handler = this;
    widget.coreProxy.clientStarted().then((Null _) {
      _initialized = true;
      if (_pendingView != null) {
        widget.coreProxy
            .newView()
            .then((viewId) => widget.coreProxy.view(viewId))
            .then((viewProxy) {
          _pendingView.complete(viewProxy);
          _pendingView = null;
        });
      }
    });
  }

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

  /// Uses a [MaterialApp] as the root of the Xi UI hierarchy.
  @override
  Widget build(BuildContext context) {
    final editor = Editor(debugBackground: widget.drawDebugBackground);
    return new MaterialApp(
        title: 'Xi',
        home: new Material(
            // required for the debug background to render correctly
            type: MaterialType.transparency,
            child: Container(
              constraints: new BoxConstraints.expand(),
              color: Colors.white,
              child: editor,
            )));
  }
}

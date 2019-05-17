// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:meta/meta.dart';
import 'package:xi_client/client.dart';

import 'document.dart';
import 'editor.dart';

/// Widget that embeds a single [Editor].
class EditorHost extends StatefulWidget {
  /// The client API interface to the xi-core Fuchsia service.
  final CoreProxy coreProxy;

  /// If `true`, draws a watermark on the editor view.
  final bool debugBackground;

  const EditorHost({
    @required this.coreProxy,
    this.debugBackground = false,
    Key key,
  })  : assert(coreProxy != null),
        super(key: key);

  @override
  State<EditorHost> createState() => EditorHostState();
}

/// State for XiApp.
class EditorHostState extends State<EditorHost> implements XiHandler {
  final Document _document = Document();

  EditorHostState();

  @override
  void initState() {
    super.initState();
    widget.coreProxy.handler = this;
    widget.coreProxy.clientStarted().then((_) => widget.coreProxy
        .newView()
        .then((viewId) => setState(
            () => _document.finalizeViewProxy(widget.coreProxy.view(viewId)))));
  }

  @override
  void alert(String text) {
    log.warning('received alert: $text');
  }

  @override
  XiViewHandler getView(String viewId) => _document;

  @override
  List<List<double>> measureWidths(List<Map<String, dynamic>> args) {
    return _document.measureWidths(args);
  }

  /// Uses a [MaterialApp] as the root of the Xi UI hierarchy.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xi',
      home: Material(
        // required for the debug background to render correctly
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints.expand(),
          color: Colors.white,
          child: Editor(
              document: _document, debugBackground: widget.debugBackground),
        ),
      ),
    );
  }
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:meta/meta.dart';
import 'package:xi_client/client.dart';
import 'package:xi_fuchsia_client/client.dart';

import 'document.dart';
import 'editor.dart';

/// Widget that embeds a single [Editor].
class EmbeddedEditor extends StatefulWidget {
  /// If `true`, draws a watermark on the editor view.
  final bool debugBackground;
  final EmbeddedClient client;

  const EmbeddedEditor({
    @required this.client,
    this.debugBackground = false,
    Key key,
  }) : super(key: key);

  @override
  State<EmbeddedEditor> createState() => EmbeddedEditorState();
}

class EmbeddedEditorState extends State<EmbeddedEditor>
    implements XiRpcHandler {
  final Document _document = Document();

  EmbeddedEditorState();

  @override
  void initState() {
    super.initState();
    widget.client.handler = this;
    _document.finalizeViewProxy(EmbeddedViewProxy(widget.client));
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

  @override
  void handleNotification(String method, dynamic params) {
    switch (method) {
      case 'update':
        Map<String, dynamic> update = params['update'];
        List<dynamic> opsList = update['ops'];
        List<Map<String, dynamic>> ops = opsList.cast();
        return _document.update(ops);
      case 'scroll_to':
        Map<String, dynamic> scrollInfo = params;
        int line = scrollInfo['line'];
        int col = scrollInfo['col'];
        return _document.scrollTo(line, col);
      default:
        log.warning('notification, unknown method $method, params=$params');
    }
  }

  @override
  dynamic handleRpc(String method, dynamic params) {
    log.warning('rpc request not handled: method="$method", params="$params"');
  }
}

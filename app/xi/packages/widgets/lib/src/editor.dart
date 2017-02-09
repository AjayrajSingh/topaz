// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'xi_app.dart';
import 'line_cache.dart';

/// Widget for one editor tab
class Editor extends StatefulWidget {
  Editor({Key key}) : super(key: key);

  @override
  EditorState createState() => new EditorState();
}

/// State for editor tab
class EditorState extends State<Editor> {
  LineCache _lines = new LineCache();

  @override
  void initState() {
    super.initState();
    XiAppState xiAppState = context.ancestorStateOfType(new TypeMatcher<XiAppState>());
    xiAppState.connectEditor(this);
  }

  /// Handler for "update" method from core
  void update(List<Map<String, dynamic>> ops) {
    setState(() => _lines.applyUpdate(ops));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[];
    int height = _lines.height;
    for (int i = 0; i < height; i++) {
      children.add(new Text(_lines.getLine(i)?.text ?? '[invalid]'));
    }
    return new Column(children: children);
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../modular/browser_module_model.dart';
import './browser.dart';

/// Document Browser app
class BrowserApp extends StatefulWidget {
  /// Each discovered Document Provider gets its own tab
  final List<Widget> tabs;

  /// Constructor for the document browser app
  const BrowserApp({
    Key key,
    @required this.tabs,
  })
      : assert(tabs != null),
        super(key: key);

  @override
  _BrowserAppState createState() => new _BrowserAppState();
}

/// Document Browser app state
class _BrowserAppState extends State<BrowserApp> with TickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    _tabController = new TabController(
      vsync: this,
      length: widget.tabs.length,
    );
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<BrowserModuleModel>(
      builder: (
        BuildContext context,
        Widget child,
        BrowserModuleModel model,
      ) {
        return new Scaffold(
          body: new Browser(
            documents: model.documents,
            currentDoc: model.currentDoc,
            onListPressed: model.list,
            onDocumentTapped: model.updateCurrentDoc,
          ),
          appBar: new AppBar(
            bottom: new TabBar(
              tabs: widget.tabs,
              controller: _tabController,
              indicatorColor: Colors.pink[200],
            ),
          ),
        );
      },
    );
  }
}

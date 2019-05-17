/// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:xi_client/client.dart';

import 'document.dart';
import 'editor.dart';
import 'editor_host.dart';

/// Widget that displays multiple editors in a tab view.
class EditorTabs extends EditorHost {
  const EditorTabs({
    @required coreProxy,
    debugBackground = false,
    Key key,
  })  : assert(coreProxy != null),
        super(key: key, coreProxy: coreProxy, debugBackground: debugBackground);

  @override
  State<EditorTabs> createState() => EditorTabsState();
}

class EditorTabsState extends State<EditorTabs>
    with TickerProviderStateMixin
    implements XiHandler {
  /// the order of views as displayed in tabs
  final List<String> _viewIds = [];

  final Map<String, Document> _documents = {};

  /// We display "Untitled 1" in the tab instead of an internal view id
  final Map<String, String> _fakeDocumentTitles = {};

  int _nextDocumentTitleNumber = 1;

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    widget.coreProxy.handler = this;
    widget.coreProxy.clientStarted().then((_) => newView());
    _tabController = TabController(vsync: this, length: 0);
  }

  void newView() {
    widget.coreProxy.newView().then((viewId) {
      setState(() {
        _viewIds.add(viewId);
        _fakeDocumentTitles[viewId] = 'Untitled $_nextDocumentTitleNumber';
        _nextDocumentTitleNumber += 1;
        _documents.putIfAbsent(viewId, () => Document());
        _documents[viewId].finalizeViewProxy(widget.coreProxy.view(viewId));
        int prevIndex = _tabController.index;
        _tabController = TabController(
            vsync: this, length: _viewIds.length, initialIndex: prevIndex)
          ..animateTo(_viewIds.length - 1);
      });
    });
  }

  void closeView(String viewId) {
    setState(() {
      log.info('closing $viewId, views: $_viewIds');
      widget.coreProxy.closeView(viewId);
      _viewIds.remove(viewId);
      _documents.remove(viewId);
      int prevIndex = _tabController.index;
      _tabController = TabController(
          vsync: this,
          length: _viewIds.length,
          initialIndex: math.max(0, math.min(prevIndex, _viewIds.length - 1)));
    });
  }

  @override
  XiViewHandler getView(String viewId) {
    // TODO: we create a new document here if one is missing, because this
    // can get called before `newView`'s future resolves. However this does mean
    // races are possible if this is called with a `viewId` of a closed view, in which case
    // we could have some zombie documents sitting around.
    _documents.putIfAbsent(viewId, () => Document());
    return _documents[viewId];
  }

  @override
  List<List<double>> measureWidths(List<Map<String, dynamic>> args) {
    if (_viewIds.first != null) {
      return _documents[_viewIds.first].measureWidths(args);
    }
    log.warning('measureWidths called with no view');
    return [];
  }

  @override
  void alert(String text) {
    // TODO: show an alert dialog?
    log.warning('core alert: $text');
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [
      IconButton(icon: Icon(Icons.add), onPressed: newView)
    ];
    if (_viewIds.length > 1) {
      actions.add(IconButton(
          icon: Icon(Icons.remove),
          onPressed: () => closeView(_viewIds[_tabController.index])));
    }

    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.pink[300],
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: actions,
          bottom: _viewIds.length > 1
              ? TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 4.0,
                  labelStyle: TextStyle(fontSize: 16.0),
                  isScrollable: true,
                  controller: _tabController,
                  tabs: _viewIds
                      .map((id) => Tab(text: _fakeDocumentTitles[id]))
                      .toList(),
                )
              : null,
        ),
        body: makeMainWidget(),
      ),
    );
  }

  Widget makeMainWidget() {
    if (_viewIds.isEmpty) {
      return Container();
    }

    if (_documents.length == 1) {
      return Editor(
          document: _documents[_viewIds[0]],
          key: Key(_viewIds[0]),
          debugBackground: widget.debugBackground);
    }

    return TabBarView(
      physics: NeverScrollableScrollPhysics(),
      controller: _tabController,
      children: _viewIds.map((id) {
        return Editor(
          document: _documents[id],
          key: Key(id),
          debugBackground: widget.debugBackground,
        );
      }).toList(),
    );
  }
}

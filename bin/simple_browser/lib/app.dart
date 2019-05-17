// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:webview/webview.dart';
import 'src/blocs/browser_bloc.dart';
import 'src/widgets/navigation_bar.dart';

class App extends StatefulWidget {
  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
  BrowserBloc _browserBloc;
  ChromiumWebView _webView;

  AppState() {
    _webView = ChromiumWebView();
    _browserBloc = BrowserBloc(webView: _webView);
  }

  @override
  void dispose() {
    _browserBloc.dispose();
    _webView.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Browser',
      home: Scaffold(
        backgroundColor: Colors.grey,
        body: Container(
          child: Column(
            children: <Widget>[
              NavigationBar(bloc: _browserBloc),
              Expanded(
                child: ChildView(
                  connection: _webView.childViewConnection,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

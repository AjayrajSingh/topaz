// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:xi_client/client.dart';

import 'home_page.dart';

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

/// State for XiApp.
class XiAppState extends State<XiApp> {
  /// Allows parent [Widget]s in either vanilla Flutter or Fuchsia to modify
  /// the [HomePage]'s [message].
  String message;

  @override
  void initState() {
    super.initState();
    config.xi.onMessage(handleMessage);
    config.xi.init();
  }

  /// Handle messages from xi-core.
  void handleMessage(String data) {
    setState(() => message = data);
  }

  /// Handler passed into [XiApp] for negotiating IPC calls to the xi-core
  /// service. Currently this is unsupported for vanilla Flutter.
  void handlePingButtonPressed() {
    String message =
        "{\"method\": \"new_tab\", \"params\": \"[]\", \"id\": 1}";

    config.xi.send(message);
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

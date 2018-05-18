// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'editor.dart';

/// Callback for when the FAB is pressed.
typedef HomePageFabPressed = void Function();

/// Example [Widget] that shows a button to ping xi-core and display a
/// [message]. [HomePage] is the
class HomePage extends StatefulWidget {
  /// [HomePage] constructor.
  const HomePage({
    @required this.onFabPressed,
    Key key,
    this.title = 'Home Page',
    this.message = '',
  })  : assert(onFabPressed != null),
        super(key: key);

  /// Callback for when the [FloatingActionButton] child [Widget] is pressed.
  final HomePageFabPressed onFabPressed;

  /// A message to display in the UI.
  final String message;

  /// A title to display in the UI.
  final String title;

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int counter = 0;
  void handleFabPressed() {
    setState(() {
      counter++;
      widget.onFabPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: const Editor(),
      floatingActionButton: new FloatingActionButton(
        onPressed: handleFabPressed,
        tooltip: 'Ping xi-core',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

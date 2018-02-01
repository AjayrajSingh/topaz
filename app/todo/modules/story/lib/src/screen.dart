// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';

import 'module_model.dart';

/// Top-level widget for the chat_story module.
class StoryScreen extends StatelessWidget {
  /// Creates a new instance of [StoryScreen].
  const StoryScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String title = 'TODO - Rust Backed Example';
    ThemeData theme = new ThemeData(primarySwatch: Colors.purple);

    return new MaterialApp(
      title: title,
      theme: theme,
      home: new Material(
        child: new ScopedModelDescendant<StoryModuleModel>(
          builder: (
            BuildContext context,
            Widget child,
            StoryModuleModel storyModel,
          ) {
            return new HomePage(title: title);
          },
        ),
      ),
    );
  }
}

/// A temporary homepage.
class HomePage extends StatelessWidget {
  /// Constructor
  const HomePage({
    Key key,
    this.title,
  })
      : super(key: key);

  /// Title to display.
  final String title;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(title),
      ),
      body: const Center(
        child: const Text('TODO: Make some UI.'),
      ),
    );
  }
}

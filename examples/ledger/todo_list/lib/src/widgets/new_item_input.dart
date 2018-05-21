// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Callback.
typedef NewItemCallback = void Function(String content);

/// Widget for entering a new todo item.
class NewItemInput extends StatefulWidget {
  /// Called when a new item is added.
  final NewItemCallback onNewItem;

  /// Constructor.
  const NewItemInput({Key key, this.onNewItem}) : super(key: key);

  @override
  _NewItemInputState createState() => new _NewItemInputState(onNewItem);
}

class _NewItemInputState extends State<NewItemInput> {
  _NewItemInputState(this.onNewItem);

  final TextEditingController _controller = new TextEditingController();
  final NewItemCallback onNewItem;

  @override
  Widget build(BuildContext context) {
    return new Row(children: <Widget>[
      new Expanded(
          child: new TextField(
              controller: _controller,
              onSubmitted: (String value) {
                onNewItem(_controller.text);
                _controller.text = '';
              },
              decoration: const InputDecoration(
                  hintText: 'What would you like to achieve today?'))),
      new SizedBox(
          width: 72.0,
          child: new IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                onNewItem(_controller.text);
                _controller.text = '';
              })),
    ]);
  }
}

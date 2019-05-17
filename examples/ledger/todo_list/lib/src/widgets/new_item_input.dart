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
  _NewItemInputState createState() => _NewItemInputState(onNewItem);
}

class _NewItemInputState extends State<NewItemInput> {
  _NewItemInputState(this.onNewItem);

  final TextEditingController _controller = TextEditingController();
  final NewItemCallback onNewItem;

  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      Expanded(
          child: TextField(
              controller: _controller,
              onSubmitted: (String value) {
                onNewItem(_controller.text);
                _controller.text = '';
              },
              decoration: InputDecoration(
                  hintText: 'What would you like to achieve today?'))),
      SizedBox(
          width: 72.0,
          child: IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                onNewItem(_controller.text);
                _controller.text = '';
              })),
    ]);
  }
}

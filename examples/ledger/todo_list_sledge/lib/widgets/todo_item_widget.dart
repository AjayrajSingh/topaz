// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

/// The data representing a single Todo.
class TodoItem {
  final String _title;

  /// Main constructor.
  TodoItem(this._title);
}

/// The widget representing a single Todo.
class TodoItemWidget extends StatelessWidget {
  final TodoItem _todoItem;

  /// Main constructor.
  const TodoItemWidget(this._todoItem);

  void _handleDeleteButtonBeingPressed() {}

  @override
  Widget build(BuildContext context) {
    TextField title = TextField(
        decoration: InputDecoration(
      hintText: _todoItem._title,
    ));

    RaisedButton deleteButton = RaisedButton(
        child: Text('Delete'),
        onPressed: _handleDeleteButtonBeingPressed);

    List<Widget> children = <Widget>[Flexible(child: title), deleteButton];

    return Row(children: children);
  }
}

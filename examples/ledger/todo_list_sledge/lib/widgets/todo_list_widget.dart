// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'todo_item_widget.dart';

/// The widget holding a list of Todos.
class TodoListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Retrieve the list of items from Sledge.
    final List<TodoItem> todoItems = <TodoItem>[]
      ..add(TodoItem('foo'))
      ..add(TodoItem('bar'))
      ..add(TodoItem('baz'));

    return ListView(
        shrinkWrap: true,
        children: todoItems
            .map((TodoItem todoItem) => TodoItemWidget(todoItem))
            .toList());
  }
}

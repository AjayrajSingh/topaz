// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import '../widgets/new_item_input.dart';
import 'todo_list_module_model.dart';

/// Widget rendering a single todo item.
class _TodoItem extends StatelessWidget {
  const _TodoItem({Key key, this.content, this.onDone}) : super(key: key);

  final String content;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);

    List<Widget> rowChildren = <Widget>[
      new Expanded(child: new Text(content)),
      new SizedBox(
        width: 72.0,
        child: new IconButton(
          icon: const Icon(Icons.done),
          color: themeData.primaryColor,
          onPressed: onDone,
        ),
      ),
    ];
    return new Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowChildren),
    );
  }
}

/// Callback type for an item becoming done.
typedef ItemDoneCallback = void Function(List<int> id);

/// The top level widget for the todo list module
class TodoListModuleScreen extends StatelessWidget {
  final double _appBarHeight = 120.0;

  /// Constructor
  const TodoListModuleScreen({Key key, this.onNewItem, this.onItemDone})
      : super(key: key);

  /// New item callback.
  final NewItemCallback onNewItem;

  /// Item done callback.
  final ItemDoneCallback onItemDone;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new ScopedModelDescendant<TodoListModuleModel>(builder: (
        BuildContext context,
        Widget child,
        TodoListModuleModel model,
      ) {
        List<Widget> listItems = <Widget>[];
        model.items.forEach((List<int> key, String value) {
          listItems.add(new _TodoItem(
            content: value,
            onDone: () {
              onItemDone(key);
            },
          ));
        });

        List<Widget> slivers = <Widget>[
          new SliverAppBar(
            expandedHeight: _appBarHeight,
            pinned: true,
            flexibleSpace: const FlexibleSpaceBar(
              title: const Text('Todo List'),
            ),
          ),
          new SliverToBoxAdapter(child: new NewItemInput(onNewItem: onNewItem)),
          new SliverList(delegate: new SliverChildListDelegate(listItems))
        ];

        return new Material(child: new CustomScrollView(slivers: slivers));
      }),
    );
  }
}

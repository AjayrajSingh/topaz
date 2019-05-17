// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

import '../models/todo_list_model.dart';
import '../widgets/new_item_input.dart';

/// Widget rendering a single todo item.
class _TodoItem extends StatelessWidget {
  const _TodoItem({Key key, this.content, this.onDone}) : super(key: key);

  final String content;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);

    List<Widget> rowChildren = <Widget>[
      Expanded(child: Text(content)),
      SizedBox(
        width: 72.0,
        child: IconButton(
          icon: Icon(Icons.done),
          color: themeData.primaryColor,
          onPressed: onDone,
        ),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
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
    return Scaffold(
      body: ScopedModelDescendant<TodoListModel>(builder: (
        BuildContext context,
        Widget child,
        TodoListModel model,
      ) {
        List<Widget> listItems = <Widget>[];
        model.items.forEach((List<int> key, String value) {
          listItems.add(_TodoItem(
            content: value,
            onDone: () {
              onItemDone(key);
            },
          ));
        });

        List<Widget> slivers = <Widget>[
          SliverAppBar(
            expandedHeight: _appBarHeight,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Todo List'),
            ),
          ),
          SliverToBoxAdapter(child: NewItemInput(onNewItem: onNewItem)),
          SliverList(delegate: SliverChildListDelegate(listItems))
        ];

        return Material(child: CustomScrollView(slivers: slivers));
      }),
    );
  }
}

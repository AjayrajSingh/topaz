// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:sledge/sledge.dart' as sledge;

import 'vote_item_widget.dart';

// TODO: remove
// ignore_for_file: unused_local_variable

// TODO: remove dynamics

class VoteListWidget extends StatefulWidget {
  @override
  VoteListWidgetState createState() => new VoteListWidgetState();
}

class VoteListWidgetState extends State<VoteListWidget> {
  static ModuleContext _moduleContext;
  sledge.Sledge _sledge;
  final List<VoteItem> _voteItems = <VoteItem>[];
  dynamic _doc;

  static final sledge.Schema _listSchema = new sledge.Schema(
      <String, sledge.BaseType>{'items': new sledge.BytelistSet()});
  static final sledge.Schema _itemSchema = VoteItem.schema;

  static set moduleContext(ModuleContext context) => _moduleContext = context;

  void _subscribeForChanges(Stream<dynamic> stream) async {
    await for (final change in stream) {
      await _sledge.runInTransaction(() async {
        await _addItems(change.insertedElements);
        _removeItems(change.deletedElements);
      });
      setState(() {
        print('Got change');
      });
    }
  }

  void _createItem(String title) {
    _sledge.runInTransaction(() async {
      final id = new sledge.DocumentId(_itemSchema);
      await _doc.items.add(id.subId);
      dynamic doc = await _sledge.getDocument(id);
      doc.title.value = title;
    });
  }

  Future<void> _addItems(Iterable<Uint8List> itemIds) async {
    for (final itemId in itemIds) {
      final itemWidget = new VoteItem(_sledge);
      await itemWidget.linkToItem(itemId);
      _voteItems.add(itemWidget);
    }
  }

  void _removeItems(Iterable<Uint8List> itemIds) async {
    for (final itemId in itemIds) {
      // TODO
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sledge == null) {
      _sledge = new sledge.Sledge.fromModule(
          _moduleContext, new sledge.SledgePageId('Vote ex'));

      _sledge.runInTransaction(() async {
        _doc = await _sledge
            .getDocument(new sledge.DocumentId.fromIntId(_listSchema, 1));
        await _addItems(_doc.items);
        _subscribeForChanges(_doc.items.onChange);
      }).then((bool b) {
        // Redraw widget, when initial list is ready.
        setState(() {});
      });
    }

    List<Widget> listItems = _voteItems
        .map((VoteItem voteItem) =>
            new Row(children: [new VoteItemWidget(voteItem)]))
        .toList()
          ..add(new Row(children: [
            new Expanded(child: new TextField(onSubmitted: _createItem))
          ]));
    return new ListView(shrinkWrap: true, children: listItems);
  }
}

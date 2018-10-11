// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:sledge/sledge.dart' as sledge;

import 'vote_item_widget.dart';

// TODO: remove dynamics

class VoteListWidget extends StatefulWidget {
  @override
  VoteListWidgetState createState() => new VoteListWidgetState();
}

class VoteListWidgetState extends State<VoteListWidget> {
  static ComponentContext _componentContext;
  sledge.Sledge _sledge;
  final List<VoteItem> _voteItems = <VoteItem>[];
  sledge.Document _doc;
  final ListEquality<int> listEquality = new ListEquality<int>();

  static final sledge.Schema _listSchema = new sledge.Schema(
      <String, sledge.BaseType>{'items': new sledge.BytelistSet()});
  static final sledge.Schema _itemSchema = VoteItem.schema;

  static set componentContext(ComponentContext context) =>
      _componentContext = context;

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
      _doc['items'].add(id.subId);
      sledge.Document doc = await _sledge.getDocument(id);
      doc['title'].value = title;
    });
  }

  void _deleteItem(sledge.DocumentId id) {
    _sledge.runInTransaction(() async {
      _doc['items'].remove(id.subId);
    });
  }

  Future _addItems(Iterable<Uint8List> itemIds) async {
    for (final itemId in itemIds) {
      final voteItem = new VoteItem(_sledge, _deleteItem);
      await voteItem.linkToItem(itemId);
      _voteItems.add(voteItem);
    }
  }

  void _removeItems(Iterable<Uint8List> itemIds) {
    for (final itemId in itemIds) {
      for (final voteItem in _voteItems) {
        if (listEquality.equals(voteItem.docSubId, itemId)) {
          _voteItems.remove(voteItem);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sledge == null) {
      _sledge = new sledge.Sledge(
          _componentContext, new sledge.SledgePageId('Vote ex'));

      _sledge.runInTransaction(() async {
        _doc = await _sledge
            .getDocument(new sledge.DocumentId.fromIntId(_listSchema, 1));
        await _addItems(_doc['items']);
        _subscribeForChanges(_doc['items'].onChange);
      }).then((bool b) {
        // Redraw widget, when initial list is ready.
        setState(() {});
      });
    }

    List<Widget> listItems = _voteItems
        .map((VoteItem voteItem) => new Row(
            children: [new VoteItemWidget(voteItem)],
            key: new Key(voteItem.docSubId.toString())))
        .toList()
          ..add(new Row(children: [
            new Expanded(child: new TextField(onSubmitted: _createItem))
          ]));
    return new ListView(shrinkWrap: true, children: listItems);
  }
}

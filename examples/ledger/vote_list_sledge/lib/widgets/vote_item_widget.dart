// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_import

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:sledge/sledge.dart' as sledge;

// TODO: remove
// ignore_for_file: unused_field, unused_local_variable

/// The data representing a single Vote.
class VoteItem {
  dynamic _doc;
  final sledge.Sledge _sledge;
  /// Schema for VoteItem.
  static final sledge.Schema schema =
      new sledge.Schema(<String, sledge.BaseType>{
    'title': new sledge.LastOneWinsString(),
    'votes': new sledge.IntCounter()
  });

  /// Main constructor.
  VoteItem(this._sledge);

  // Should be run only in transaction.
  /// Links this to [itemId].
  Future<void> linkToItem(Uint8List itemId) async {
    _doc = await _sledge.getDocument(new sledge.DocumentId(schema, itemId));
  }

}

/// The widget representing a single Vote.
class VoteItemWidget extends StatefulWidget {
  final VoteItem _voteItem;

  /// Main constructor.
  const VoteItemWidget(this._voteItem);

  @override
  VoteItemState createState() => new VoteItemState(_voteItem);
}

class VoteItemState extends State<VoteItemWidget> {
  VoteItem _voteItem;

  VoteItemState(this._voteItem) {
    _subscribeForChanges(_voteItem._doc.votes.onChange);
  }

  void _handlePlusPressed() {
    _voteItem._sledge.runInTransaction(() async {
      _voteItem._doc.votes.add(1);
    });
  }

  void _subscribeForChanges(Stream<int> stream) async {
    await for (int x in stream) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final counterButton = new Container(
        child: new IconButton(
            icon: new Icon(Icons.star),
            color: Colors.red[500],
            onPressed: _handlePlusPressed));

    final counterCnt =
        new Container(child: new Text('${_voteItem._doc.votes.value}'));

    final title = new Container(child: new Text(_voteItem._doc.title.value));

    return new Row(children: [title, counterButton, counterCnt]);
  }
}

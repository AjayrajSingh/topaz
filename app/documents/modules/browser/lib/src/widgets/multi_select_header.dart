// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:fidl_documents/fidl.dart' as doc_fidl;

const double _kDefaultFontSize = 14.0;

/// The bar that appears at the top of the module, and says how many
/// items are currently selected
class MultiSelectHeader extends StatelessWidget {
  /// List of selected documents
  final List<doc_fidl.Document> documents;

  /// Function to call when we close the multi-select overlay
  final VoidCallback onClosePressed;

  /// Constructor
  const MultiSelectHeader({
    @required this.onClosePressed,
    @required this.documents,
    Key key,
  })  : assert(onClosePressed != null),
        assert(documents != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    String item = documents.length > 1 ? 'items' : 'item';
    return new Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      color: Colors.teal[300],
      child: new Row(
        children: <Widget>[
          new IconButton(
            icon: const Icon(Icons.close),
            color: Colors.black,
            onPressed: onClosePressed,
          ),
          new Expanded(
            child: new Text(
              '${documents.length} $item selected',
              style: const TextStyle(
                fontSize: _kDefaultFontSize,
              ),
            ),
          ),
          const IconButton(
            icon: const Icon(Icons.create_new_folder),
            color: Colors.black,
            onPressed: null, // TODO SO-816
          ),
          const IconButton(
            icon: const Icon(Icons.more_vert),
            color: Colors.black,
            onPressed: null, // TODO SO-816
          ),
        ],
      ),
    );
  }
}

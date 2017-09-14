// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/modular.dart';

import '../../models.dart';
import 'list_item.dart';

/// The UI widget that represents a list of contacts
class ContactList extends StatefulWidget {
  /// Creates a new instance of [ContactList]
  ContactList({Key key}) : super(key: key);

  @override
  _ContactListState createState() => new _ContactListState();
}

class _ContactListState extends State<ContactList> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(primarySwatch: Colors.blue),
      home: new Material(
        child: new ScopedModelDescendant<ContactListModel>(builder: (
          BuildContext context,
          Widget child,
          ContactListModel model,
        ) {
          return new ListView(
            children: model.contactList.map((ContactListItem c) {
              return new ListItem(
                contact: c,
                isFirstInCategory: model.firstItems.contains(c),
              );
            }).toList(),
          );
        }),
      ),
    );
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import '../models/actions.dart';
import '../models/contact_item.dart';

/// A UI widget representing the list item in the contact list
///
/// Shows a letter if it is the first item starting with that character,
/// an avatar, and the contact display name
class ContactListItem extends StatelessWidget {
  /// The contact information to display
  final ContactItem contact;

  /// Handle user tap on the list item
  final ContactTappedAction onContactTapped;

  /// Boolean representing if this is the first list item
  final bool isFirstInCategory;

  /// Constructor
  const ContactListItem({
    Key key,
    @required this.contact,
    @required this.onContactTapped,
    this.isFirstInCategory = false,
  })  : assert(contact != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      child: new Row(
        children: <Widget>[
          new Container(
            margin: const EdgeInsets.only(left: 10.0),
            width: 40.0,
            child: new Center(
              child: new Text(isFirstInCategory ? contact.firstLetter : ''),
            ),
          ),
          new Container(
            margin: const EdgeInsets.all(10.0),
            width: 40.0,
            child: new Alphatar.fromNameAndUrl(
              name: contact.displayName,
              avatarUrl: contact.photoUrl,
            ),
          ),
          new Flexible(
            child: new Text(
              contact.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: () {
        onContactTapped(contact);
      },
    );
  }
}

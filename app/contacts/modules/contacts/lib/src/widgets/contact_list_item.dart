// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'type_defs.dart';

/// UI widget representing a [Contact] in list view
class ContactListItem extends StatelessWidget {
  /// [Contact] for this list item
  final Contact contact;

  /// Callback if item is selected
  final ContactActionCallback onSelect;

  /// Constructor
  const ContactListItem({
    Key key,
    @required this.contact,
    this.onSelect,
  })
      : assert(contact != null),
        super(key: key);

  void _handleSelect() {
    onSelect?.call(contact);
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = new Container(
      child: new Alphatar.fromNameAndUrl(
        name: contact.displayName,
        avatarUrl: contact.photoUrl,
      ),
    );

    return new Material(
      color: Colors.white,
      child: new ListTile(
        enabled: true,
        onTap: _handleSelect,
        isThreeLine: false,
        leading: avatar,
        title: new Text(contact.displayName),
      ),
    );
  }
}

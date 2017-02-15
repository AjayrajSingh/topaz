// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'contact_details_group.dart';
import 'contact_details_row.dart';
import 'type_defs.dart';

/// A widget representing a group of email address for the ContactsDetails view
class EmailDetailsGroup extends StatelessWidget {
  /// List of email addresses to show
  final List<EmailAddress> emailAddresses;

  /// Callback for when a email address is selected
  final EmailAddressActionCallback onSelectEmailAddress;

  /// Constructor
  EmailDetailsGroup({
    Key key,
    @required this.emailAddresses,
    this.onSelectEmailAddress,
  })
      : super(key: key) {
    assert(emailAddresses != null);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = emailAddresses
        .map((EmailAddress emailAddress) => new ContactDetailsRow(
            label: emailAddress.label,
            child: new Text(
              emailAddress.value,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: new TextStyle(
                fontSize: 16.0,
              ),
            ),
            onSelect: () {
              onSelectEmailAddress?.call(emailAddress);
            }))
        .toList();
    return new ContactDetailsGroup(
      child: new Column(children: children),
      icon: Icons.mail,
    );
  }
}

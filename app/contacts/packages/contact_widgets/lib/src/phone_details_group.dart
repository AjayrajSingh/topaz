// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:contact_models/contact.dart';

import 'contact_details_group.dart';
import 'contact_details_row.dart';
import 'type_defs.dart';

/// A widget representing a group of email address for the ContactsDetails view
class PhoneDetailsGroup extends StatelessWidget {
  /// List of phone numbers to show
  final List<PhoneNumber> phoneNumbers;

  /// Callback for when a phone number is selected
  final PhoneNumberActionCallback onSelectPhoneNumber;

  /// Constructor
  PhoneDetailsGroup({
    Key key,
    @required this.phoneNumbers,
    this.onSelectPhoneNumber,
  })
      : super(key: key) {
    assert(phoneNumbers != null);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = phoneNumbers
        .map((PhoneNumber phoneNumber) => new ContactDetailsRow(
            label: phoneNumber.label,
            child: new Text(
              phoneNumber.number,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: new TextStyle(
                fontSize: 16.0,
              ),
            ),
            onSelect: () {
              onSelectPhoneNumber?.call(phoneNumber);
            }))
        .toList();
    return new ContactDetailsGroup(
      child: new Column(children: children),
      icon: Icons.phone,
    );
  }
}

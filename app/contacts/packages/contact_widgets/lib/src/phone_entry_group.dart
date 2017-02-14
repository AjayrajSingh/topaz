// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:contact_models/contact.dart';

import 'contact_entry_group.dart';
import 'contact_entry_row.dart';
import 'type_defs.dart';

/// A widget representing a contact group of phone entries (phone numbers)
class PhoneEntryGroup extends StatelessWidget {
  /// List of phone entries to show
  final List<PhoneEntry> phoneEntries;

  /// Callback for when a phone entry is selected
  final PhoneActionCallback onSelectPhoneEntry;

  /// Constructor
  PhoneEntryGroup({
    Key key,
    @required this.phoneEntries,
    this.onSelectPhoneEntry,
  })
      : super(key: key) {
    assert(phoneEntries != null);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = phoneEntries
        .map((PhoneEntry entry) => new ContactEntryRow(
            label: entry.label,
            child: new Text(
              entry.number,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: new TextStyle(
                fontSize: 16.0,
              ),
            ),
            onSelect: () {
              onSelectPhoneEntry?.call(entry);
            }))
        .toList();
    return new ContactEntryGroup(
      child: new Column(children: children),
      icon: Icons.phone,
    );
  }
}

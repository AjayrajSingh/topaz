// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';

import '../stores/contact_item_store.dart';

const String _kDividerChar = ' - ';
const TextStyle _kDetailStyle = const TextStyle(color: Colors.grey);
const TextStyle _kBoldStyle = const TextStyle(fontWeight: FontWeight.bold);

/// Callback type that passes in a contact item.
typedef void ContactItemCallback(ContactItemStore contact);

/// A UI widget representing the list item in the contact list
///
/// Shows an avatar, the contact's full name, and the detail
/// Example: (avatar) full name - detail
///
/// Bolds the part of the contact that matched the prefix
class ContactItem extends StatelessWidget {
  /// The part of the contact's display name that was matched
  final String matchedPrefix;

  /// The contact information to display
  final ContactItemStore contact;

  /// Called when this item is tapped
  final ContactItemCallback onTap;

  /// Constructor
  const ContactItem({
    Key key,
    @required this.matchedPrefix,
    @required this.contact,
    this.onTap,
  })  : assert(contact != null),
        assert(matchedPrefix != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new ListTile(
      leading: new Alphatar.fromNameAndUrl(
        name: contact.fullName,
        avatarUrl: contact.photoUrl,
      ),
      title: new RichText(
        text: new TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: _getDisplayText(),
        ),
      ),
      onTap: () => onTap(contact),
    );
  }

  List<TextSpan> _getDisplayText() {
    return contact.isMatchedOnName
        ? _getTextWithNameBolded()
        : _getTextWithDetailBolded();
  }

  List<TextSpan> _getTextWithNameBolded() {
    List<TextSpan> displayText = <TextSpan>[];
    int i = contact.matchedNameIndex;
    String delimiter = ContactItemStore.nameDelimiter;

    // E.g. given a prefix of "bet" and names ["Alpha", "Beta", "Gamma", "E"]:
    // beforeBolded = "Alpha"
    // boldText = "Bet"
    // unboldedPortion = "a"
    // remainingName = "Gamma E"
    String beforeBolded = contact.names.sublist(0, i).join(delimiter);
    String boldedText = contact.names[i].substring(0, matchedPrefix.length);
    String unboldedPortion = contact.names[i].substring(matchedPrefix.length);
    String remainingName = contact.names.sublist(i + 1).join(delimiter);

    if (beforeBolded.isNotEmpty) {
      displayText.add(new TextSpan(text: beforeBolded));
    }

    displayText.add(new TextSpan(
      text: beforeBolded.isNotEmpty ? '$delimiter$boldedText' : boldedText,
      style: _kBoldStyle,
    ));

    if (unboldedPortion.isNotEmpty || remainingName.isNotEmpty) {
      StringBuffer remaining = new StringBuffer()
        ..write(unboldedPortion.isNotEmpty ? unboldedPortion : '')
        ..write(remainingName.isNotEmpty ? '$delimiter$remainingName' : '');
      displayText.add(new TextSpan(text: remaining.toString()));
    }

    // Add greyed out detail text with the divider
    if (contact.detail.isNotEmpty) {
      displayText.add(new TextSpan(
        text: '$_kDividerChar${contact.detail}',
        style: _kDetailStyle,
      ));
    }
    return displayText;
  }

  List<TextSpan> _getTextWithDetailBolded() {
    String boldedText = contact.detail.substring(0, matchedPrefix.length);
    String unboldedPortion = contact.detail.substring(matchedPrefix.length);
    List<TextSpan> displayText = <TextSpan>[
      new TextSpan(text: contact.fullName),
      const TextSpan(text: _kDividerChar, style: _kDetailStyle),
      new TextSpan(
        text: boldedText,
        style: _kDetailStyle.merge(_kBoldStyle),
      ),
    ];

    if (unboldedPortion.isNotEmpty) {
      displayText.add(
        new TextSpan(text: unboldedPortion, style: _kDetailStyle),
      );
    }

    return displayText;
  }
}

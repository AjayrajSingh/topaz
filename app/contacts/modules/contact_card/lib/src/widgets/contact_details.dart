// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.schemas.dart/com.fuchsia.contact.dart' as entities;
import 'package:meta/meta.dart';

const double _kIconSize = 14.0;
const TextStyle _kDetail = const TextStyle(fontSize: 13.0);
const TextStyle _kLabel = const TextStyle(fontSize: 10.0);

/// Widget to display the details about a contact
class ContactDetails extends StatelessWidget {
  final entities.ContactEntityData _contact;

  /// Instantiate a contact detail widget with the contact information
  const ContactDetails({@required entities.ContactEntityData contact})
      : assert(contact != null),
        _contact = contact;

  @override
  Widget build(BuildContext context) {
    Divider divider = const Divider(height: 1.0, color: Colors.grey);
    List<Widget> contactDetails = <Widget>[divider];

    for (entities.PhoneNumberEntityData number in _contact.phoneNumbers) {
      contactDetails.add(
        new ListTile(
          leading: number == _contact.phoneNumbers.first
              ? const Icon(Icons.phone, size: _kIconSize)
              : const Icon(null),
          title: new Text(number.number, style: _kDetail),
          subtitle: new Text(number.label, style: _kLabel),
        ),
      );
    }

    for (entities.EmailEntityData email in _contact.emailAddresses) {
      Icon icon = const Icon(null);
      if (email == _contact.emailAddresses.first) {
        contactDetails.add(divider);
        icon = const Icon(Icons.email, size: _kIconSize);
      }
      contactDetails.add(
        new ListTile(
          leading: icon,
          title: new Text(email.value, style: _kDetail),
          subtitle: new Text(email.label, style: _kLabel),
        ),
      );
    }

    return new ListView(children: contactDetails);
  }
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'address_details_group.dart';
import 'email_details_group.dart';
import 'phone_details_group.dart';
import 'type_defs.dart';

/// Contact Details that usually contains information about a contact's phone
/// number, email addresses and addresses,
class ContactDetails extends StatelessWidget {
  /// User [Contact] that is being rendered
  final Contact contact;

  /// Callback when given address is selected
  final AddressActionCallback onSelectAddress;

  /// Callback when given email address is selected
  final EmailAddressActionCallback onSelectEmailAddress;

  /// Callback when given phone number is selected
  final PhoneNumberActionCallback onSelectPhoneNumber;

  /// Constructor
  ContactDetails({
    Key key,
    @required this.contact,
    this.onSelectAddress,
    this.onSelectEmailAddress,
    this.onSelectPhoneNumber,
  })
      : super(key: key) {
    assert(contact != null);
  }

  void _handleSelectEmailAddress(EmailAddress emailAddress) {
    onSelectEmailAddress?.call(emailAddress);
  }

  void _handleSelectPhoneNumber(PhoneNumber phoneNumber) {
    onSelectPhoneNumber?.call(phoneNumber);
  }

  void _handleSelectAddress(Address address) {
    onSelectAddress?.call(address);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> entryGroups = <Widget>[];
    Widget divider = new Container(
      margin: const EdgeInsets.only(left: 90.0),
      decoration: new BoxDecoration(
        border: new Border(
          top: new BorderSide(
            color: Colors.grey[300],
          ),
        ),
      ),
    );

    if (contact.phoneNumbers.isNotEmpty) {
      entryGroups.add(new Container(
        padding: const EdgeInsets.all(16.0),
        child: new PhoneDetailsGroup(
          phoneNumbers: contact.phoneNumbers,
          onSelectPhoneNumber: _handleSelectPhoneNumber,
        ),
      ));
    }

    if (contact.emailAddresses.isNotEmpty) {
      if (entryGroups.isNotEmpty) {
        entryGroups.add(divider);
      }
      entryGroups.add(new Container(
        padding: const EdgeInsets.all(16.0),
        child: new EmailDetailsGroup(
          emailAddresses: contact.emailAddresses,
          onSelectEmailAddress: _handleSelectEmailAddress,
        ),
      ));
    }

    if (contact.addresses.isNotEmpty) {
      if (entryGroups.isNotEmpty) {
        entryGroups.add(divider);
      }
      entryGroups.add(new Container(
        padding: const EdgeInsets.all(16.0),
        child: new AddressDetailsGroup(
          addresses: contact.addresses,
          onSelectAddress: _handleSelectAddress,
        ),
      ));
    }

    return new Material(
      color: Colors.white,
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: entryGroups,
      ),
    );
  }
}

// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import 'contact_details_group.dart';
import 'contact_details_row.dart';
import 'type_defs.dart';

/// A widget representing a group of address for the ContactsDetails view
class AddressDetailsGroup extends StatelessWidget {
  /// List of addresses to show
  final List<Address> addresses;

  /// Callback for when a address is selected
  final AddressActionCallback onSelectAddress;

  /// Constructor
  const AddressDetailsGroup({
    Key key,
    @required this.addresses,
    this.onSelectAddress,
  })
      : assert(addresses != null),
        super(key: key);

  Widget _buildAddressLine(String line) {
    return new Text(
      line,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16.0,
      ),
    );
  }

  Widget _buildAddress(Address address) {
    List<Widget> addressLines = <Widget>[];

    if (address.street != null) {
      addressLines.add(_buildAddressLine(address.street));
    }

    if (address.city != null ||
        address.region != null ||
        address.postalCode != null) {
      StringBuffer lineBuffer = new StringBuffer();
      if (address.city != null) {
        lineBuffer.write(address.city);
      }
      if (address.region != null) {
        lineBuffer.write(address.region);
      }
      if (address.postalCode != null) {
        lineBuffer.write(address.postalCode);
      }
      addressLines.add(_buildAddressLine(lineBuffer.toString()));
    }

    if (address.country != null) {
      addressLines.add(_buildAddressLine(address.country));
    }

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: addressLines,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = addresses
        .map((Address address) => new ContactDetailsRow(
            label: address.label,
            child: _buildAddress(address),
            onSelect: () {
              onSelectAddress?.call(address);
            }))
        .toList();
    return new ContactDetailsGroup(
      child: new Column(children: children),
      icon: Icons.place,
    );
  }
}

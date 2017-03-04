// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts/src/models.dart';
import 'package:contacts/src/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Test to see if tapping on a single address will call the appropriate '
      'callbacks', (WidgetTester tester) async {
    List<Address> addresses = <Address>[
      new Address(
        label: 'Work',
        street: 'Work Street',
      ),
      new Address(
        label: 'Home',
        street: 'Home Street',
      ),
    ];

    int workAddressTaps = 0;

    await tester.pumpWidget(new StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return new Material(
        child: new AddressDetailsGroup(
          addresses: addresses,
          onSelectAddress: (Address address) {
            workAddressTaps++;
            expect(address, addresses[0]);
          },
        ),
      );
    }));

    expect(workAddressTaps, 0);
    await tester.tap(find.text(addresses[0].label));
    expect(workAddressTaps, 1);
  });
}

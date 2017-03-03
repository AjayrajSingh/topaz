// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/models.dart';
import '../../lib/src/widgets.dart';

void main() {
  testWidgets(
      'Test to see if tapping on a single phone number '
      'will call the appropriate callbacks', (WidgetTester tester) async {
    List<PhoneNumber> phoneNumbers = <PhoneNumber>[
      new PhoneNumber(
        label: 'Work',
        number: '13371337',
      ),
      new PhoneNumber(
        label: 'Home',
        number: '10101010',
      ),
    ];

    int workPhoneTaps = 0;

    await tester.pumpWidget(new StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return new Material(
        child: new PhoneDetailsGroup(
          phoneNumbers: phoneNumbers,
          onSelectPhoneNumber: (PhoneNumber phoneNumber) {
            workPhoneTaps++;
            expect(phoneNumber, phoneNumbers[0]);
          },
        ),
      );
    }));

    expect(workPhoneTaps, 0);
    await tester.tap(find.text(phoneNumbers[0].label));
    expect(workPhoneTaps, 1);
  });
}

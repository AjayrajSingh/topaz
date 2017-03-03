// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/models.dart';
import '../../lib/src/widgets.dart';

void main() {
  testWidgets(
      'Test to see if tapping on a single email address '
      'will call the appropriate callbacks', (WidgetTester tester) async {
    List<EmailAddress> emails = <EmailAddress>[
      new EmailAddress(
        label: 'Work',
        value: 'coco@work',
      ),
      new EmailAddress(
        label: 'Home',
        value: 'coco@home',
      ),
    ];

    int workEmailTaps = 0;

    await tester.pumpWidget(new StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return new Material(
        child: new EmailDetailsGroup(
          emailAddresses: emails,
          onSelectEmailAddress: (EmailAddress address) {
            workEmailTaps++;
            expect(address, emails[0]);
          },
        ),
      );
    }));

    expect(workEmailTaps, 0);
    await tester.tap(find.text(emails[0].label));
    expect(workEmailTaps, 1);
  });
}

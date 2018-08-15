// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_picker/stores.dart';
import 'package:test/test.dart';

void main() {
  group('ContactItemStore', () {
    test('should throw if isMatchedOnName is true but there is no index', () {
      expect(() {
        new ContactItemStore(
          id: 'id',
          names: <String>['ada'],
          isMatchedOnName: true,
        );
      }, throwsA(const TypeMatcher<Exception>()));
    });

    test('should throw if isMatchedOnName is true and index < 0', () {
      expect(() {
        new ContactItemStore(
          id: 'id',
          names: <String>['ada'],
          isMatchedOnName: true,
          matchedNameIndex: -10,
        );
      }, throwsA(const TypeMatcher<Exception>()));
    });

    test('should throw if isMatchedOnName is true and index > length', () {
      expect(() {
        new ContactItemStore(
          id: 'id',
          names: <String>['ada'],
          isMatchedOnName: true,
          matchedNameIndex: 1,
        );
      }, throwsA(const TypeMatcher<Exception>()));
    });

    test('fullName should include all name components in order', () {
      List<String> nameComponents = <String>[
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ];
      ContactItemStore contact = new ContactItemStore(
        id: '1',
        names: nameComponents,
        isMatchedOnName: false,
      );

      expect(contact.fullName, equals(nameComponents.join(' ')));
    });
  });
}

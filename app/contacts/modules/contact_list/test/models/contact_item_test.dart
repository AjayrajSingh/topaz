// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contact_list/models.dart';
import 'package:test/test.dart';

void main() {
  group('ContactItem', () {
    test('should throw if display name is empty', () {
      expect(() {
        new ContactItem(id: 'id', displayName: '');
      }, throwsA(const TypeMatcher<AssertionError>()));
    });

    test('should throw if id is empty', () {
      expect(() {
        new ContactItem(id: '', displayName: 'displayName');
      }, throwsA(const TypeMatcher<AssertionError>()));
    });

    test(
        'should return # as first letter when display name begins with a number',
        () {
      ContactItem item =
          new ContactItem(id: 'id', displayName: '931 Gilman Street');
      expect(item.firstLetter, equals('#'));
    });
  });
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/src/module/intent.dart'; // ignore: implementation_imports

import 'package:test/test.dart';

import '../matchers.dart';

void main() {
  group('intent constructors', () {
    test('intent sets the action', () {
      final intent = Intent(action: 'my-action')
        ..addParameterFromEntityReference('my-value', 'foo');
      expect(intent.action, 'my-action');
    });

    test('intent with handler sets the handler', () {
      final intent = Intent(action: '', handler: 'my-handler');
      expect(intent.handler, 'my-handler');
    });
  });

  group('intent parameters', () {
    Intent intent;

    setUp(() {
      intent = Intent(action: 'foo');
    });

    test('addParameterFromEntityReference adds it to the list', () {
      intent.addParameterFromEntityReference('name', 'ref');
      final result = intent.parameters.firstWhere((p) => p.name == 'name');
      expect(result, isNotNull);
    });

    test('getEntity throws for missing name', () {
      expect(() {
        intent.getEntity(name: 'not-a-name', type: 'foo');
      }, throwsModuleStateException);
    });
  });
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:modular/src/module/intent.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

import '../matchers.dart';

void main() {
  group('intent constructors', () {
    test('intentWithAction sets the action', () {
      final intent = Intent.withAction('my-action')
        ..addParameterFromEntityReference('my-value', 'foo');
      expect(intent.action, 'my-action');
    });

    test('intentWithHandler sets the handler', () {
      final intent = Intent.withHandler('my-handler');
      expect(intent.handler, 'my-handler');
    });
  });

  group('intent parameters', () {
    Intent intent;

    setUp(() {
      intent = Intent.withAction('foo');
    });

    test('addParameterFromEntityReference it to the list', () {
      intent.addParameterFromEntityReference('name', 'ref');
      final result = intent.parameters.firstWhere((p) => p.name == 'name');
      expect(result, isNotNull);
    });

    test('getParameter throws for missing name', () {
      expect(() {
        intent.getParameter('not-a-name');
      }, throwsModuleStateException);
    });

    test('getParameter returns the transformed intent', () {
      intent.addParameterFromEntityReference('name', 'ref');
      expect(intent.getParameter('name'), isIntentParameter);
    });

    test('getParameter throws for unsupported union type', () {
      intent.parameters.add(fidl.IntentParameter(
          name: 'name',
          data: fidl.IntentParameterData.withLinkName('my-link')));

      expect(() {
        intent.getParameter('name');
      }, throwsModuleStateException);
    });
  });
}

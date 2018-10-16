// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:test/test.dart';

import 'package:fuchsia_modular/src/module/_intent_handler_impl.dart'; // ignore: implementation_imports
import 'package:fuchsia_modular/src/module/intent.dart'; // ignore: implementation_imports

void main() {
  group('intent handler impl', () {
    final IntentHandlerImpl impl =
        IntentHandlerImpl(startupContext: StartupContext.fromStartupInfo());

    test('handleIntent calls registered handler', () {
      bool onHandleCalled = false;
      impl
        ..onHandleIntent = (_) {
          onHandleCalled = true;
        }
        ..handleIntent(_fidlIntent());
      expect(onHandleCalled, isTrue);
    });

    test('handleIntent passes along the correct action', () async {
      String calledAction;

      impl.onHandleIntent = (i) => calledAction = i.action;

      await impl.handleIntent(_fidlIntent(action: 'foo-action'));
      expect(calledAction, 'foo-action');
    });

    test('Should translate the entity intent parameters', () async {
      Intent handledIntent;
      impl.onHandleIntent = (intent) => handledIntent = intent;

      await impl.handleIntent(
        _fidlIntent(
            parameters: [_fidlEntityIntentParameter(name: 'entity-intent')]),
      );

      expect(handledIntent.getParameter('entity-intent'), isNotNull);
    });
  });
}

fidl.Intent _fidlIntent({
  String action = '',
  List<fidl.IntentParameter> parameters = const [],
}) {
  return fidl.Intent(action: action, handler: null, parameters: parameters);
}

fidl.IntentParameter _fidlEntityIntentParameter({String name = ''}) {
  return fidl.IntentParameter(
    data: fidl.IntentParameterData.withEntityReference('ref'),
    name: name,
  );
}

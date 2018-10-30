// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:fuchsia_modular/src/module/internal/_intent_handler_impl.dart'; // ignore: implementation_imports
import 'package:fuchsia_modular/src/module/internal/_module_impl.dart'; // ignore: implementation_imports
import 'package:fuchsia_modular/src/module/intent.dart'; // ignore: implementation_imports
import 'package:fuchsia_modular/src/module/intent_handler.dart'; // ignore: implementation_imports
import 'package:fuchsia_modular/src/module/noop_intent_handler.dart'; // ignore: implementation_imports

const fidl.Intent _emptyIntent = fidl.Intent(
  action: '',
  handler: '',
  parameters: [],
);

// Mock classes
class MockLifecycle extends Mock implements Lifecycle {}

void main() {
  ModuleImpl mod;
  IntentHandlerImpl handlerImpl;

  setUp(() {
    handlerImpl =
        IntentHandlerImpl(startupContext: StartupContext.fromStartupInfo());
    mod = ModuleImpl(intentHandlerImpl: handlerImpl);
  });

  group('intent handling', () {
    test('throws when registerIntentHandler called twice', () {
      mod.registerIntentHandler(NoopIntentHandler());

      expect(() {
        mod.registerIntentHandler(NoopIntentHandler());
      }, throwsException);
    });

    test('throws when no intent handler registered', () {
      expect(handlerImpl.handleIntent(_emptyIntent), throwsException);
    });

    test('module proxies intents to handler', () {
      bool didHandleIntent = false;
      final handler = _StubIntentHandler()
        ..onDidHandleIntent = () => didHandleIntent = true;

      mod.registerIntentHandler(handler);
      handlerImpl.handleIntent(_emptyIntent);
      expect(didHandleIntent, isTrue);
    });
  });

  test('verify Lifecycle init during the construction of ModuleImpl', () {
    final mockLifecycle = MockLifecycle();
    ModuleImpl(intentHandlerImpl: handlerImpl, lifecycle: mockLifecycle);
    verify(mockLifecycle.addTerminateListener(any));
  });

  test('embed module throws for empty name', () {
    expect(
        mod.embedModule(name: '', intent: _emptyIntent), throwsArgumentError);
  });
}

class _StubIntentHandler implements IntentHandler {
  void Function() onDidHandleIntent;

  @override
  void handleIntent(Intent intent) {
    if (onDidHandleIntent != null) {
      onDidHandleIntent();
    }
  }
}

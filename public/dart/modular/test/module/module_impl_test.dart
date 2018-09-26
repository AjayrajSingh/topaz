// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fuchsia/services.dart';
import 'package:test/test.dart';

import 'package:modular/src/module/_intent_handler_host.dart'; // ignore: implementation_imports
import 'package:modular/src/module/_module_impl.dart'; // ignore: implementation_imports
import 'package:modular/src/module/intent_handler.dart'; // ignore: implementation_imports
import 'package:modular/src/module/noop_intent_handler.dart'; // ignore: implementation_imports

const fidl.Intent _emptyIntent = fidl.Intent(
  action: '',
  handler: '',
  parameters: [],
);

void main() {
  ModuleImpl mod;
  IntentHandlerHost host;

  setUp(() {
    host = IntentHandlerHost(startupContext: StartupContext.fromStartupInfo());
    mod = ModuleImpl(intentHandlerHost: host);
  });

  group('intent handling', () {
    test('throws when registerIntentHandler called twice', () {
      mod.registerIntentHandler(NoopIntentHandler());

      expect(() {
        mod.registerIntentHandler(NoopIntentHandler());
      }, throwsException);
    });

    test('throws when no intent handler registered', () {
      expect(host.handleIntent(_emptyIntent), throwsException);
    });

    test('module proxies intents to handler', () {
      bool didHandleIntent = false;
      final handler = _StubIntentHandler()
        ..onDidHandleIntent = () => didHandleIntent = true;

      mod.registerIntentHandler(handler);
      host.handleIntent(_emptyIntent);
      expect(didHandleIntent, isTrue);
    });
  });
}

class _StubIntentHandler implements IntentHandler {
  void Function() onDidHandleIntent;

  @override
  void handleIntent(String name, Intent intent) {
    if (onDidHandleIntent != null) {
      onDidHandleIntent();
    }
  }
}

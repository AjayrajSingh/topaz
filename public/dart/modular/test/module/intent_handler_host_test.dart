// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/services.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/module/_intent_handler_host.dart';

void main() {
  group('intent handler host', () {
    test('handleIntent calls registered handler', () {
      bool onHandleCalled = false;
      IntentHandlerHost(
        startupContext: StartupContext.fromStartupInfo(),
      )
        ..onHandleIntent = (_, __) {
          onHandleCalled = true;
        }
        ..handleIntent(null);
      expect(onHandleCalled, isTrue);
    });
  });
}

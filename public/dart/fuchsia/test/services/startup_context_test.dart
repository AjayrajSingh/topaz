// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'package:fuchsia/src/services/startup_context.dart'; // ignore: implementation_imports

void main() {
  group('StartupContext', () {
    test('fromStartupInfo does not return null instance', () {
      expect(StartupContext.fromStartupInfo(), isNotNull);
    });

    test('fromStartupInfo returns the same instance', () {
      expect(
          StartupContext.fromStartupInfo(), StartupContext.fromStartupInfo());
    });
  });
}

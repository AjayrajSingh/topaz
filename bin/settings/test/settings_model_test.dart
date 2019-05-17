// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:settings/src/models/settings_model.dart'; // ignore: implementation_imports
import 'package:test/test.dart';

class TestSettingsModel extends SettingsModel {
  @override
  void initialize() {}
}

void main() {
  TestSettingsModel _settingsModel = TestSettingsModel();

  test('test buildInfo', () {
    final DateTime testDate = DateTime.utc(2006, 10, 6, 13, 20, 0);
    _settingsModel.testDeviceSourceDate = testDate;
    expect(
        _settingsModel.buildInfo, equals('Built at 13:20 UTC on Oct 06, 2006'));
  });
}

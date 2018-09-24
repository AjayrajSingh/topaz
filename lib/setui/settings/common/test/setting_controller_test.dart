// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_controller.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockTestAdapter extends Mock implements SettingAdapter {}

void main() {
  // Make sure mappings call the correct underlying mapping.
  test('test_setting_controller_mapping', () async {
    verifyMapping<WirelessState>(SettingType.wireless);
    verifyMapping<ConnectedState>(SettingType.connectivity);
    verifyMapping<TimeZoneInfo>(SettingType.timeZone);
  });
}

void verifyMapping<T>(SettingType type) {
  final MockTestAdapter adapter = MockTestAdapter();
  when(adapter.fetch(type)).thenReturn(SettingSource<T>());
  SettingController<T>(adapter).fetch();
  verify(adapter.fetch(type));
}

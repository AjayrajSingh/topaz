// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:test/test.dart';

void main() {
  // Exercises json encoding of setting log.
  test('test_setting_log_json', () async {
    final TimeZone tz1 = TimeZone(id: '1', name: 'foo', region: ['foo1']);
    final TimeZone tz2 = TimeZone(id: '2', name: 'bar', region: ['bar2']);

    final AdapterLog log1 = AdapterLog.withSetting(
        DateTime.now(),
        SettingLog(SettingsObject(
            settingType: SettingType.timeZone,
            data: SettingData.withTimeZoneValue(
                TimeZoneInfo(available: [tz1, tz2], current: tz2)))));

    final AdapterLog log2 = AdapterLog.fromJson(jsonDecode(jsonEncode(log1)));

    expect(log1.time, log2.time);
    expect(log1.settingLog.settings.settingType,
        log2.settingLog.settings.settingType);

    // FIDL parsing is covered by the fidl-gen tests.
  });

  // Exercises json encoding of fetch log.
  test('test_fetch_log_json', () async {
    final AdapterLog adapterLog1 = AdapterLog.withFetch(
        DateTime.now(), FetchLog(SettingType.connectivity));

    final AdapterLog adapterLog2 =
        AdapterLog.fromJson(jsonDecode(jsonEncode(adapterLog1)));

    expect(adapterLog1.fetchLog.type, adapterLog2.fetchLog.type);
  });
}

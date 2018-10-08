// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:lib_setui_settings_testing/mock_setting_adapter.dart';
import 'package:test/test.dart';

void main() {
  /// The following test ensures events are executed and held according to the
  /// replay timeline. In the following scenario, we should see the following:
  /// 1. client fetch of time zone
  /// 2. time zone update from server
  /// 3. client fetch of connectivity
  /// 4. time zone update from server
  /// 5. connectivity update from server.
  test('test_log_test', () async {
    final List<AdapterLog> logs = [];

    final DateTime epoch = DateTime.now();

    final TimeZone tz1 = TimeZone(region: [], id: 'tz1', name: 'timezone1');
    final TimeZone tz2 = TimeZone(region: [], id: 'tz2', name: 'timezone2');

    final SettingsObject tzSettings1 = SettingsObject(
        settingType: SettingType.timeZone,
        data: SettingData.withTimeZoneValue(
            TimeZoneInfo(available: [tz1], current: null)));

    final SettingsObject tzSettings2 = SettingsObject(
        settingType: SettingType.timeZone,
        data: SettingData.withTimeZoneValue(
            TimeZoneInfo(available: [tz1, tz2], current: tz1)));

    final SettingsObject connectivitySettings1 = SettingsObject(
        settingType: SettingType.connectivity,
        data: SettingData.withConnectivity(
            ConnectedState(reachability: Reachability.wan)));

    logs
      ..add(AdapterLog.withFetch(
          epoch.add(Duration(seconds: 1)), FetchLog(SettingType.timeZone)))
      ..add(AdapterLog.withSetting(
          epoch.add(Duration(seconds: 2)), SettingLog(tzSettings1)))
      ..add(AdapterLog.withFetch(
          epoch.add(Duration(seconds: 3)), FetchLog(SettingType.connectivity)))
      ..add(AdapterLog.withSetting(
          epoch.add(Duration(seconds: 4)), SettingLog(tzSettings2)))
      ..add(AdapterLog.withSetting(
          epoch.add(Duration(seconds: 5)), SettingLog(connectivitySettings1)));

    TestExecutor executor = TestExecutor();

    final MockSettingAdapter adapter =
        MockSettingAdapter(logs, executor: executor.capture);

    // 1. Fetch time zone
    final SettingSource<TimeZoneInfo> tzSource =
        adapter.fetch(SettingType.timeZone);

    expect(executor.actions.length, 1);

    // 2. Time zone returned from server
    executor.playback();
    expect(tzSource.state, tzSettings1.data.timeZoneValue);

    // 3. Fetch connectivity
    final SettingSource<ConnectedState> connectedSource =
        adapter.fetch(SettingType.connectivity);

    expect(executor.actions.length, 2);

    // 4. Time zone returned from server
    executor.playback();
    expect(tzSource.state, tzSettings2.data.timeZoneValue);

    // 5. Connectivity returned from server
    executor.playback();
    expect(connectedSource.state, connectivitySettings1.data.connectivity);
  });
}

class TestExecutor {
  List<LogAction> actions = [];

  void capture(Duration delay, LogAction action) {
    actions.add(action);
  }

  void playback() {
    if (actions.isEmpty) {
      return;
    }

    actions.removeAt(0)();
  }
}

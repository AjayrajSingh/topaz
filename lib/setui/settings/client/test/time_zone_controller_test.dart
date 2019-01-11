// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_client/time_zone_controller.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_model.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockTestAdapter extends Mock implements SettingAdapter {}

class MockTimeZoneSettingSource extends Mock
    implements SettingSource<TimeZoneInfo> {}

void main() {
  // Exercises the TimeZoneController functionality, retrieving and setting the
  // time zone state.
  test('test_controller_interaction', () async {
    final TimeZone current = TimeZone(id: '1', name: 'tz1', region: []);
    // Fixture data handed back through the mock adapter.
    final TimeZoneInfo state = TimeZoneInfo(
        available: [current, TimeZone(id: '2', name: 'tz2', region: [])],
        current: current);

    final MockTestAdapter adapter = MockTestAdapter();

    // Hand back a mock setting source wrapping the fixture data.
    when(adapter.fetch(SettingType.timeZone)).thenAnswer((_) {
      final MockTimeZoneSettingSource source = MockTimeZoneSettingSource();
      when(source.state).thenReturn(state);

      return source;
    });

    final TimeZoneController controller = TimeZoneController(adapter);

    // Upon fetch, make sure fixture is handed back.
    final SettingModel<TimeZoneInfo> model = controller.fetch();
    expect(model.state, state);

    final TimeZone firstTimeZone = model.state.available[0];

    // When setting the time zone, make sure adapter is notified with the
    // correctly modified state.
    controller.setCurrentTimeZone(firstTimeZone);

    final TimeZoneInfo updatedState =
        verify(adapter.mutate(SettingType.timeZone, captureAny))
            .captured
            .single
            .timeZoneMutationValue
            .value;

    expect(updatedState.current, firstTimeZone);
    expect(updatedState.available, state.available);
  });
}

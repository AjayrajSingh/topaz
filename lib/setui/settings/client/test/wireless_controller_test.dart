// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_client/wireless_controller.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_model.dart';
import 'package:lib_setui_settings_common/setting_source.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockTestAdapter extends Mock implements SettingAdapter {}

class MockWirelessSource extends Mock implements SettingSource<WirelessState> {}

void main() {
  // Exercises the NetworkController functionality, retrieving and setting the
  // current wireless network.
  test('test_controller_interaction', () async {
    final WirelessAccessPoint accessPoint = WirelessAccessPoint(
        accessPointId: Random().nextInt(1000),
        name: 'accessPoint',
        password: null,
        rssi: Random().nextInt(1000),
        security: WirelessSecurity.secured,
        status: null);

    final WirelessState state = WirelessState(accessPoints: [accessPoint]);

    final MockTestAdapter adapter = MockTestAdapter();

    // Hand back a mock setting source wrapping the fixture data.
    when(adapter.fetch(SettingType.wireless)).thenAnswer((_) {
      final MockWirelessSource source = MockWirelessSource();
      when(source.state).thenReturn(state);
      return source;
    });

    final WirelessController controller = WirelessController(adapter);

    // Upon fetch, make sure fixture is handed back.
    final SettingModel<WirelessState> model = controller.fetch();
    expect(model.state, state);

    const String testPassword = 'TestPassword123';

    controller.connect(accessPoint, testPassword);

    final WirelessState updatedState =
        verify(adapter.update(captureAny)).captured.single.data.wireless;

    // The state should house a single interface.
    expect(updatedState.accessPoints.length, 1);

    final WirelessAccessPoint updatedAccessPoint = updatedState.accessPoints[0];

    // id and password should match.
    expect(updatedAccessPoint.accessPointId, accessPoint.accessPointId);
    expect(updatedAccessPoint.password, testPassword);
    expect(updatedAccessPoint.status, ConnectionStatus.connected);
  });
}

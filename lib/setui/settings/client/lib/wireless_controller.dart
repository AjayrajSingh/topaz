// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_controller.dart';

// A controller for interacting with the wireless networks.
class WirelessController extends SettingController<WirelessState> {
  WirelessController(SettingAdapter adapter) : super(adapter);

  /// Connects to the specified [WirelessAccessPoint].
  void connect(WirelessAccessPoint accessPoint, String password) {
    WirelessAccessPoint point = WirelessAccessPoint(
      accessPointId: accessPoint.accessPointId,
      name: null,
      password: password,
      rssi: null,
      security: null,
      status: ConnectionStatus.connected,
    );

    update(SettingsObject(
        settingType: SettingType.wireless,
        data: SettingData.withWireless(WirelessState(accessPoints: [point]))));
  }
}

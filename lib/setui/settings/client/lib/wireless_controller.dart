// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_controller.dart';

class WirelessController extends SettingController<WirelessState> {
  WirelessController(SettingAdapter adapter) : super(adapter);
}

/// STOPSHIP(brycelee): re-enable once Migration is complete
// /// A controller for interacting with the wireless networks.
// class WirelessController extends SettingController<WirelessState> {
//   WirelessController(SettingAdapter adapter) : super(adapter);

//   final WirelessUiState uiState = WirelessUiState();

//   /// Enter in a password and connect to the currently selected point
//   Future<void> password(String password) async {
//     uiState._passwordShowing.value = false;
//     await _connect(uiState.selectedAccessPoint, password: password);
//   }

//   /// Called when the user dismisses the password dialog
//   void dismissPassword() {
//     _reset();
//   }

//   void _reset() {
//     uiState._passwordShowing.value = false;
//     uiState._selectedAccessPoint.value = null;
//   }

//   /// Connects to the specified [WirelessAccessPoint].
//   ///
//   /// If the access point requires password, then show password dialog if needed
//   Future<void> connect(WirelessAccessPoint accessPoint) async {
//     uiState._selectedAccessPoint.value = accessPoint;

//     if (accessPoint.security == WirelessSecurity.secured &&
//         accessPoint.password == null) {
//       uiState._passwordShowing.value = true;
//     } else {
//       await _connect(accessPoint);
//     }
//   }

//   Future<void> _connect(WirelessAccessPoint accessPoint,
//       {String password}) async {
//     final updatedAccessPoint = WirelessAccessPoint.clone(accessPoint,
//         status: ConnectionStatus.connected, password: password);

//     await update(SettingsObject(
//         settingType: SettingType.wireless,
//         data: SettingData.withWireless(
//             WirelessState(accessPoints: [updatedAccessPoint]))));
//     _reset();
//   }
// }

// class WirelessUiState extends ChangeNotifier {
//   final ValueNotifier<bool> _passwordShowing = ValueNotifier<bool>(false);
//   final ValueNotifier<WirelessAccessPoint> _selectedAccessPoint =
//       ValueNotifier<WirelessAccessPoint>(null);

//   WirelessUiState() {
//     _passwordShowing.addListener(notifyListeners);
//     _selectedAccessPoint.addListener(notifyListeners);
//   }

//   bool get passwordShowing => _passwordShowing.value;
//   WirelessAccessPoint get selectedAccessPoint => _selectedAccessPoint.value;
// }

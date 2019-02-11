// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_controller.dart';

/// A controller for interacting with the wireless networks.
class WirelessController extends SettingController<WirelessState> {
  WirelessController(SettingAdapter adapter) : super(adapter);

  final WirelessUiState uiState = WirelessUiState();

  /// Enter in a password and connect to the currently selected point
  Future<void> password(String password) async {
    uiState._passwordSubmitted(password);
    await _connect();
  }

  /// Called when the user dismisses the password dialog
  void dismissPassword() {
    uiState._passwordDismissed();
  }

  /// Connects to the specified [WirelessAccessPoint].
  ///
  /// If the access point requires password, then show password dialog if needed
  Future<void> select(WirelessNetwork network) async {
    if (uiState._networkSelected(network)) {
      await _connect();
    }
  }

  Future<void> _connect() async {
    // TODO: mutate
    uiState._reset();
  }
}

class WirelessUiState extends ChangeNotifier {
  final ValueNotifier<CurrentScreen> _screen =
      ValueNotifier(CurrentScreen.main);
  final ValueNotifier<WirelessNetwork> _selectedAccessPoint =
      ValueNotifier<WirelessNetwork>(null);
  final ValueNotifier<String> _password = ValueNotifier(null);

  WirelessUiState() {
    _screen.addListener(notifyListeners);
    _password.addListener(notifyListeners);
    _selectedAccessPoint.addListener(notifyListeners);
  }

  // Returns true if the selection should result in immediate connection
  bool _networkSelected(WirelessNetwork network) {
    _selectedAccessPoint.value = network;
    if (network.wpaAuth != WpaAuth.noneOpen) {
      _screen.value = CurrentScreen.passwordShowing;
    } else {
      _screen.value = CurrentScreen.connecting;
      return true;
    }
    return false;
  }

  void _passwordSubmitted(String password) {
    _password.value = password;
    _screen.value = CurrentScreen.connecting;
  }

  void _passwordDismissed() {
    _reset();
  }

  void _reset() {
    _screen.value = CurrentScreen.main;
    _selectedAccessPoint.value = null;
    _password.value = null;
  }

  CurrentScreen get screen => _screen.value;
  WirelessNetwork get selectedAccessPoint => _selectedAccessPoint.value;
}

enum CurrentScreen {
  main,
  passwordShowing,
  connecting,
}

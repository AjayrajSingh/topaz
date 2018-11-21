import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_net/fidl.dart' as net;
import 'package:lib.app.dart/app.dart';

import 'setui_setting_controller.dart';

class ConnectivityController extends SetUiSettingController {
  net.ConnectivityProxy _connectivity;
  bool _reachable;

  @override
  Future<void> close() async {
    _connectivity.ctrl.close();
  }

  @override
  Future<void> initialize() async {
    Completer<void> completer = Completer();

    _connectivity = net.ConnectivityProxy();
    connectToService(StartupContext.fromStartupInfo().environmentServices,
        _connectivity.ctrl);

    _connectivity.onNetworkReachable = (reachable) {
      // Wait for initital state before being done initializing.
      if (_reachable != reachable) {
        _reachable = reachable;
        _connectivity.onNetworkReachable = _updateReachable;
        completer.complete();
      }
    };
    return completer.future;
  }

  void _updateReachable(bool reachable) {
    if (_reachable != reachable) {
      _reachable = reachable;
      notifyListeners();
    }
  }

  @override
  Future<bool> setSettingValue(SettingsObject value) async {
    return false;
  }

  @override
  SettingsObject get value => SettingsObject(
      settingType: SettingType.connectivity,
      data: SettingData.withConnectivity(ConnectedState(
          reachability: _reachable ? Reachability.wan : Reachability.unknown)));
}

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';

import 'setting_controller.dart';
import 'timezone_controller.dart';

class LocalSetUiService implements SetUiService {
  Map<SettingType, SettingController> controllers = {};
  final SettingControllerCreator creator;
  final SetUiListenerProxyBinder proxyBinder;

  LocalSetUiService(
      {this.creator = SettingControllerCreator.instance,
      this.proxyBinder = _bindListenerProxy});

  @override
  void listen(
      SettingType settingType, InterfaceHandle<SettingListener> listener) {
    _getController(settingType).addListener(proxyBinder(listener));
  }

  @override
  void update(
      SettingsObject value, void Function(UpdateResponse response) callback) {
    _getController(value.settingType).setSetting(value).then((success) {
      callback(UpdateResponse(
          returnCode: success ? ReturnCode.ok : ReturnCode.failed));
    });
  }

  SettingController _getController(SettingType type) =>
      controllers.putIfAbsent(type, () => creator.createController(type));
}

class SettingControllerCreator {
  static const SettingControllerCreator instance = SettingControllerCreator();

  const SettingControllerCreator();

  SettingController createController(SettingType type) {
    switch (type) {
      case SettingType.timeZone:
        return TimeZoneController();
      default:
        throw UnimplementedError('No controller for the given type!');
    }
  }
}

SettingListenerProxy _bindListenerProxy(
    InterfaceHandle<SettingListener> listener) {
  final proxy = SettingListenerProxy();
  proxy.ctrl.bind(listener);
  return proxy;
}

typedef SetUiListenerProxyBinder = SettingListenerProxy Function(
    InterfaceHandle<SettingListener> listener);

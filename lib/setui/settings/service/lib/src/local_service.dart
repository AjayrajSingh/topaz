import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';

import 'connectivity_controller.dart';
import 'network_controller.dart';
import 'setui_setting_controller.dart';
import 'timezone_controller.dart';

class LocalSetUiService implements SetUiService {
  Map<SettingType, SetUiSettingController> controllers = {};
  final SetUiSettingControllerCreator creator;
  final SetUiListenerProxyBinder proxyBinder;

  LocalSetUiService(
      {this.creator = SetUiSettingControllerCreator.instance,
      this.proxyBinder = _bindListenerProxy});

  @override
  void listen(
      SettingType settingType, InterfaceHandle<SettingListener> listener) {
    _getController(settingType).addListener(proxyBinder(listener));
  }

  @override
  void update(
      SettingsObject value, void Function(UpdateResponse response) callback) {
    // TODO: Remove this method and replace with mutate.
  }

  @override
  void mutate(SettingType settingType, Mutation mutation,
      void Function(MutationResponse response) callback) {
    interactiveMutate(settingType, mutation, null /*handles*/, callback);
  }

  @override
  void interactiveMutate(
      SettingType settingType,
      Mutation mutation,
      MutationHandles handles,
      void Function(MutationResponse response) callback) {
    _getController(settingType).mutate(mutation, handles: handles).then((code) {
      callback(MutationResponse(returnCode: code));
    });
  }

  SetUiSettingController _getController(SettingType type) =>
      controllers.putIfAbsent(type, () => creator.createController(type));
}

class SetUiSettingControllerCreator {
  static const SetUiSettingControllerCreator instance =
      SetUiSettingControllerCreator();

  const SetUiSettingControllerCreator();

  SetUiSettingController createController(SettingType type) {
    switch (type) {
      case SettingType.timeZone:
        return TimeZoneController();
      case SettingType.wireless:
        return NetworkController();
      case SettingType.connectivity:
        return ConnectivityController();
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

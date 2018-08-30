import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:flutter/material.dart';

import 'src/local_service.dart';

/// Library that wraps the underlying setUi service.
///
/// Can be used to swap out between different implementations.
/// A [SetUiListenerBinder] can be passed in to provide alternative
/// binding forms (such as in linux host tests).
class SetUiServiceManager {
  final SetUiService _service;
  final SetUiListenerBinder _listenerBinder;

  factory SetUiServiceManager(
      {SetUiService service, SetUiListenerBinder binder = _bindListener}) {
    return service != null
        ? SetUiServiceManager.withService(service, binder)
        : SetUiServiceManager._local(binder);
  }

  SetUiServiceManager.withService(this._service, this._listenerBinder);

  SetUiServiceManager._local(this._listenerBinder)
      : _service = LocalSetUiService();

  /// Gets the setting from the service with the given [SettingType].
  ///
  /// [T] must be the type returned by the service for the given SettingType
  /// as documented in fuchsia.setui.types.fidl.
  SettingsObjectNotifier<T> getSetting<T>(SettingType settingType) {
    final notifier = SettingsObjectNotifier<T>();
    _service.listen(settingType, _listenerBinder(notifier));
    return notifier;
  }

  /// Updates the setting based on [SettingsObject]'s type.
  Future<UpdateResponse> setSetting(SettingsObject object) async {
    Completer<UpdateResponse> c = Completer<UpdateResponse>();

    _service.update(object, (response) {
      c.complete(response);
    });

    return c.future;
  }
}

/// [T] must be within the list of structs in the union class of SettingsData
class SettingsObjectNotifier<T> extends ChangeNotifier
    implements SettingListener {
  final ValueNotifier<T> _valueNotifier = ValueNotifier<T>(null);

  SettingsObjectNotifier() {
    _valueNotifier.addListener(notifyListeners);
  }

  T get value => _valueNotifier.value;

  @override
  Future<Null> notify(SettingsObject object) async {
    _valueNotifier.value = object.data.$data;
  }
}

typedef SetUiListenerBinder = InterfaceHandle<SettingListener> Function(
    SettingListener impl);

InterfaceHandle<SettingListener> _bindListener(SettingListener impl) =>
    SettingListenerBinding().wrap(impl);

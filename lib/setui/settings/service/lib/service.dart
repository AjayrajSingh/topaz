import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:lib_setui_settings_common/setting_adapter.dart';
import 'package:lib_setui_settings_common/setting_source.dart';

import 'src/local_service.dart';

/// Library that wraps the underlying setUi service.
///
/// Can be used to swap out between different implementations.
/// A [SetUiListenerBinder] can be passed in to provide alternative
/// binding forms (such as in linux host tests).
class SetUiServiceAdapter implements SettingAdapter {
  final SetUiService _service;
  final SetUiListenerBinder _listenerBinder;

  factory SetUiServiceAdapter(
      {SetUiService service, SetUiListenerBinder binder = _bindListener}) {
    return service != null
        ? SetUiServiceAdapter.withService(service, binder)
        : SetUiServiceAdapter._local(binder);
  }

  SetUiServiceAdapter.withService(this._service, this._listenerBinder);

  SetUiServiceAdapter._local(this._listenerBinder)
      : _service = LocalSetUiService();

  /// Gets the setting from the service with the given [SettingType].
  ///
  /// [T] must be the type returned by the service for the given SettingType
  /// as documented in fuchsia.setui.types.fidl.
  @override
  SettingSource<T> fetch<T>(SettingType settingType) {
    final notifier = SettingSource<T>();
    _service.listen(settingType, _listenerBinder(notifier));
    return notifier;
  }

  /// Updates the setting based on [SettingsObject]'s type.
  @override
  Future<UpdateResponse> update(SettingsObject object) async {
    Completer<UpdateResponse> c = Completer<UpdateResponse>();

    _service.update(object, (response) {
      c.complete(response);
    });

    return c.future;
  }
}

typedef SetUiListenerBinder = InterfaceHandle<SettingListener> Function(
    SettingListener impl);

InterfaceHandle<SettingListener> _bindListener(SettingListener impl) =>
    SettingListenerBinding().wrap(impl);

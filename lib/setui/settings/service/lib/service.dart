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
  final Map<SettingType, SettingSource> _sources = {};
  final AdapterLogger _logger;

  int nextUpdateId = 0;

  int _nextMutationId = 0;

  factory SetUiServiceAdapter(
      {SetUiService service,
      SetUiListenerBinder binder = _bindListener,
      AdapterLogger logger}) {
    final SetUiServiceAdapter adapter = service != null
        ? SetUiServiceAdapter.withService(service, binder, logger)
        : SetUiServiceAdapter._local(binder, logger);

    return adapter;
  }

  SetUiServiceAdapter.withService(
      this._service, this._listenerBinder, this._logger);

  SetUiServiceAdapter._local(this._listenerBinder, this._logger)
      : _service = LocalSetUiService();

  /// Gets the setting from the service with the given [SettingType].
  ///
  /// [T] must be the type returned by the service for the given SettingType
  /// as documented in fuchsia.setui.types.fidl.
  @override
  SettingSource<T> fetch<T>(SettingType settingType) {
    if (!_sources.containsKey(settingType)) {
      _sources[settingType] = ObservableSettingSource<T>(_logger);
    }

    final ObservableSettingSource<T> notifier = _sources[settingType];

    _service.listen(settingType, _listenerBinder(notifier));
    _logger?.onFetch(FetchLog(settingType));

    return notifier;
  }

  /// Updates the setting based on [SettingsObject]'s type.
  @override
  Future<UpdateResponse> update(SettingsObject object) async {
    final int nextUpdateId = this.nextUpdateId++;

    _logger?.onUpdate(UpdateLog(nextUpdateId, object));

    Completer<UpdateResponse> c = Completer<UpdateResponse>();

    _service.update(object, (response) {
      _logger?.onResponse(ResponseLog(nextUpdateId, response));
      c.complete(response);
    });

    return c.future;
  }

  @override
  Future<MutationResponse> mutate(SettingType settingType, Mutation mutation,
      {MutationHandles handles}) async {
    final int nextMutationId = _nextMutationId++;

    _logger?.onMutation(MutationLog(nextMutationId, settingType, mutation));

    Completer<MutationResponse> completer = Completer<MutationResponse>();

    void callback(MutationResponse response) {
      completer.complete(response);
    }

    if (handles != null) {
      _service.interactiveMutate(settingType, mutation, handles, callback);
    } else {
      _service.mutate(settingType, mutation, callback);
    }
    return completer.future;
  }
}

// A source that can be instrumented to capture updates.
class ObservableSettingSource<T> extends SettingSource<T> {
  final AdapterLogger _logger;

  ObservableSettingSource(this._logger);

  @override
  Future<Null> notify(SettingsObject object) {
    _logger?.onSettingLog(SettingLog(object));
    return super.notify(object);
  }
}

typedef SetUiListenerBinder = InterfaceHandle<SettingListener> Function(
    SettingListener impl);

InterfaceHandle<SettingListener> _bindListener(SettingListener impl) =>
    SettingListenerBinding().wrap(impl);

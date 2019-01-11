// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';

import 'setting_adapter.dart';
import 'setting_model.dart';
import 'setting_source.dart';

/// Base controller that handles interaction with the underlying setting adapter
/// and access to the state data.
class SettingController<T> {
  final SettingAdapter _adapter;
  SettingSource<T> _source;

  SettingController(this._adapter);

  /// Returns a setting model that will be updated with the latest state.
  SettingModel<T> fetch() {
    _source ??= _adapter.fetch(settingType);

    return SettingModel<T>(_source);
  }

  SettingType get settingType {
    switch (T) {
      case TimeZoneInfo:
        return SettingType.timeZone;
      case WirelessState:
        return SettingType.wireless;
      case ConnectedState:
        return SettingType.connectivity;
    }

    throw new Exception('Undefined setting type!');
  }

  Future<void> mutate(Mutation mutation, MutationHandles handles) async {
    await _adapter.mutate(settingType, mutation, handles: handles);
  }

  /// Updates the setting state to the provided version.
  Future<void> update(SettingsObject state) async {
    await _adapter.update(state);
  }

  /// Returns the most current data from source.
  T get state => _source.state;
}

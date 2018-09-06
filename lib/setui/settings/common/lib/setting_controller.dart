// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_setui/fidl.dart';

import 'setting_adapter.dart';
import 'setting_model.dart';
import 'setting_source.dart';

/// Base controller that handles interaction with the underlying setting adapter
/// and access to the state data.
abstract class SettingController<T> {
  final SettingAdapter _adapter;
  SettingSource<T> _source;

  SettingController(this._adapter);

  /// Returns a setting model that will be updated with the latest state.
  SettingModel<T> fetch() {
    _source ??= _adapter.fetch(type);

    return SettingModel<T>(_source);
  }

  SettingType get type;

  /// Updates the setting state to the provided version.
  void update(SettingsObject state) {
    _adapter.update(state);
  }

  /// Returns the most current data from source.
  T get state => _source.state;
}

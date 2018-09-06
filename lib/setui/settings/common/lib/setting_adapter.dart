// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';

import 'setting_source.dart';

/// An interface for accessing settings.
///
/// Adapters are meant for controllers, who expose a narrower interaction
/// surface to the clients.
abstract class SettingAdapter {
  /// Retrieves the current setting source.
  SettingSource<T> fetch<T>(SettingType settingType);

  /// Applies the updated values to the backend.
  Future<UpdateResponse> update(SettingsObject updatedSetting);
}

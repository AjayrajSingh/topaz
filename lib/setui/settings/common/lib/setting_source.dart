// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:flutter/widgets.dart';

/// An accessor for settings.
///
/// [SettingSource] extends [ChangeNotifier] to provide updates on changes to
/// owners. For example, a model may wrap [SettingSource] for the view layer and
/// register its notify method as the change callback.
class SettingSource<T> extends ChangeNotifier implements SettingListener {
  final ValueNotifier<T> _valueNotifier = ValueNotifier<T>(null);

  SettingSource() {
    _valueNotifier.addListener(notifyListeners);
  }

  /// The current setting.
  T get state => _valueNotifier.value;

  @override
  Future<Null> notify(SettingsObject object) async {
    _valueNotifier.value = object.data.$data;
  }
}

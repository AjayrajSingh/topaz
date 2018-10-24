// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';

/// An accessor for settings.
///
/// [SettingSource] extends [ChangeNotifier] to provide updates on changes to
/// owners. For example, a model may wrap [SettingSource] for the view layer and
/// register its notify method as the change callback.
class SettingSource<T> implements SettingListener {
  T _value;

  final StreamController<T> _streamController =
      new StreamController<T>.broadcast();

  StreamSubscription<T> addListener(void callback(T value)) =>
      _streamController.stream.listen(callback);

  /// The current setting.
  T get state => _value;

  @override
  Future<Null> notify(SettingsObject object) async {
    _value = object.data.$data;
    _streamController.add(_value);
  }
}

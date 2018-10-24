// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:lib.widgets/model.dart';

import 'setting_source.dart';

/// A wrapper around settings data to notify widgets on new data.
class SettingModel<T> extends Model {
  SettingSource<T> _source;

  SettingModel(this._source) {
    _source.addListener((value) => notifyListeners());
  }

  T get state => _source.state;
}

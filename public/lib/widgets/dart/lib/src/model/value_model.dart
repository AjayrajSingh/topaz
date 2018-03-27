// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';

/// [ValueModel] is a simple [Model] object which wraps an object
/// that does not extend [Model]. Its purpose is to call [Model#notifyListeners]
/// when the value changes.
///
/// Note: the values stored inside of the model are not watched so changes to
/// a mutable model object will not trigger updates.
class ValueModel<T> extends Model {
  T _value;

  /// Initializes the model with an initial value.
  ValueModel({
    T value,
  }) : _value = value;

  /// Returns the current value of this model
  T get value => _value;

  /// Sets the current value of this model and
  /// calls [notifyListeners].
  set value(T newValue) {
    _value = newValue;
    notifyListeners();
  }
}

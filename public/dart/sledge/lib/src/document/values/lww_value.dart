// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base_value.dart';
import 'converter.dart';
import 'key_value.dart';

class _LastOneWinValue<T> {
  T _value, _transaction;
  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();

  _LastOneWinValue(this._value);

  Stream<T> get onChange => _changeController.stream;

  set value(T value) => _transaction = value;

  T get value => _transaction ?? _value;

  Map<int, T> put() {
    if (_transaction == null) {
      return <int, T>{};
    }
    var result = <int, T>{0: _transaction};
    _value = _transaction;
    _transaction = null;
    return result;
  }

  void applyChanges(Map<int, T> change) {
    if (change.isEmpty) {
      return;
    }
    if (change.length != 1 || change[0] == null) {
      throw new FormatException('Changes have not supported format.', change);
    }
    _value = change[0];
    _changeController.add(_value);
  }
}

/// Sledge Last-Write-Win value.
class LastOneWinValue<T> implements BaseValue<T> {
  final _LastOneWinValue _value;
  final DataConverter<int, T> _converter;

  /// Constructor
  LastOneWinValue([List<KeyValue> init])
      : _converter = new DataConverter<int, T>(),
        _value = new _LastOneWinValue<T>(new Converter<T>().defaultValue) {
    applyChanges(init ?? <KeyValue>[]);
  }

  @override
  List<KeyValue> put() => _converter.serialize(_value.put());

  @override
  void applyChanges(List<KeyValue> input) =>
      _value.applyChanges(_converter.deserialize(input));

  /// Sets value.
  set value(T value) => _value.value = value;

  /// Gets value.
  T get value => _value.value;

  @override
  Stream<T> get onChange => _value.onChange;
}

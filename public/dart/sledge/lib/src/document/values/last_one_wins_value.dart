// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base_value.dart';
import '../change.dart';
import 'converted_change.dart';
import 'converter.dart';

class _LastOneWinsValue<T> {
  T _value, _localChange;
  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();

  _LastOneWinsValue(this._value);

  Stream<T> get onChange => _changeController.stream;

  set value(T value) => _localChange = value;

  T get value => _localChange ?? _value;

  ConvertedChange<int, T> getChange() {
    if (_localChange == null) {
      return new ConvertedChange<int, T>();
    }
    var result = new ConvertedChange<int, T>(<int, T>{0: _localChange});
    _value = _localChange;
    _localChange = null;
    return result;
  }

  void applyChange(ConvertedChange<int, T> change) {
    if (change.changedEntries.isEmpty) {
      return;
    }
    if (change.deletedKeys.isNotEmpty) {
      throw new FormatException('Should be no deleted keys.', change);
    }
    if (change.changedEntries.length != 1 ||
        !change.changedEntries.containsKey(0)) {
      throw new FormatException('Changes have not supported format.', change);
    }
    _value = change.changedEntries[0];
    _changeController.add(_value);
  }
}

/// Sledge Last One Wins value.
class LastOneWinsValue<T> extends BaseValue<T> {
  final _LastOneWinsValue _value;
  final DataConverter<int, T> _converter;

  /// Default constructor.
  LastOneWinsValue([Change init])
      : _converter = new DataConverter<int, T>(),
        _value = new _LastOneWinsValue<T>(new Converter<T>().defaultValue) {
    applyChange(init ?? new Change());
  }

  @override
  Change getChange() => _converter.serialize(_value.getChange());

  @override
  void applyChange(Change input) =>
      _value.applyChange(_converter.deserialize(input));

  /// Sets value.
  set value(T value) {
    _value.value = value;
    observer.valueWasChanged();
  }

  /// Gets value.
  T get value => _value.value;

  @override
  Stream<T> get onChange => _value.onChange;
}

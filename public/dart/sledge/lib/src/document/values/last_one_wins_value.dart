// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../change.dart';
import '../leaf_value.dart';
import '../value_observer.dart';
import 'converted_change.dart';
import 'converter.dart';

class _LastOneWinsValue<T> {
  T _value;
  T _valueToRollback;
  final StreamController<T> _changeController =
      StreamController<T>.broadcast();

  _LastOneWinsValue(this._value);

  Stream<T> get onChange => _changeController.stream;

  set value(T value) {
    _valueToRollback = _valueToRollback ?? _value;
    _value = value;
  }

  T get value => _value;

  ConvertedChange<int, T> getChange() {
    if (_valueToRollback == null) {
      // If there's nothing to rollback, no changes have been done.
      return ConvertedChange<int, T>();
    }
    return ConvertedChange<int, T>(<int, T>{0: _value});
  }

  void applyChange(ConvertedChange<int, T> change) {
    if (change.changedEntries.isEmpty) {
      return;
    }
    if (change.deletedKeys.isNotEmpty) {
      throw FormatException(
          'There should be no deleted keys. Found `${change.deletedKeys}`.',
          change);
    }
    if (change.changedEntries.length != 1 ||
        !change.changedEntries.containsKey(0)) {
      throw FormatException('Changes have unsupported format.', change);
    }
    _value = change.changedEntries[0];
    _changeController.add(_value);
  }

  void completeTransaction() {
    _valueToRollback = null;
  }

  void rollbackChange() {
    if (_valueToRollback != null) {
      _value = _valueToRollback;
      _valueToRollback = null;
    }
  }
}

/// Sledge Last One Wins value.
class LastOneWinsValue<T> implements LeafValue {
  final _LastOneWinsValue _value;
  final MapToKVListConverter<int, T> _converter;
  ValueObserver _observer;

  /// Default constructor.
  LastOneWinsValue([Change init])
      : _converter = MapToKVListConverter<int, T>(),
        _value = _LastOneWinsValue<T>(Converter<T>().defaultValue) {
    applyChange(init ?? Change());
  }

  @override
  Change getChange() => _converter.serialize(_value.getChange());

  @override
  void completeTransaction() {
    _value.completeTransaction();
  }

  @override
  void applyChange(Change input) {
    _value.applyChange(_converter.deserialize(input));
  }

  @override
  void rollbackChange() {
    _value.rollbackChange();
  }

  @override
  Stream<T> get onChange => _value.onChange;

  @override
  set observer(ValueObserver observer) {
    _observer = observer;
  }

  /// Sets the current value.
  set value(T value) {
    _value.value = value;
    _observer?.valueWasChanged();
  }

  /// Returns the current value.
  T get value => _value.value;
}

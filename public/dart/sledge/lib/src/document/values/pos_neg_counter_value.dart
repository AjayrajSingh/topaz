// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base_value.dart';
import '../change.dart';
import 'converted_change.dart';
import 'converter.dart';
import 'key_value_storage.dart';

/// Implementation of Positive Negative Counter CRDT.
/// For each instance we create a pair of monotonically increasing variables:
/// one to accumulate increments, and another to accumulate decrements. The
/// total value of the counter is the sum, over all instances, of the difference
/// between the positive and negative variable.
/// Each variable pair may be modified by only one instance, so the
/// Last One Wins merge strategy works.
class _PosNegCounterValue<T extends num> {
  final KeyValueStorage<int, T> _storage;
  final int _currentInstanceId;
  T _sum;
  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();

  _PosNegCounterValue(this._currentInstanceId, T defaultValue)
      : _storage = new KeyValueStorage<int, T>(defaultValue) {
    _sum = _storage.defaultValue;
  }

  int get _positiveKey => 2 * _currentInstanceId;
  int get _negativeKey => 2 * _currentInstanceId + 1;
  bool _isKeyPositive(int key) => key > 0 && key.isEven;

  Stream<T> get onChange => _changeController.stream;

  void add(T delta) {
    if (delta > 0) {
      _addPositiveValue(_positiveKey, delta);
    } else {
      _addPositiveValue(_negativeKey, -delta);
    }
    _sum += delta;
  }

  T get value => _sum;

  void _addPositiveValue(int key, T delta) {
    T cur = _storage[key];
    _storage[key] = cur + delta;
  }

  ConvertedChange<int, T> put() => _storage.put();

  void applyChanges(ConvertedChange<int, T> change) {
    for (var key in change.changedEntries.keys) {
      var diff = change.changedEntries[key] - _storage[key];
      if (_isKeyPositive(key)) {
        _sum += diff;
      } else {
        _sum -= diff;
      }
    }
    _storage.applyChanges(change);
    _changeController.add(_sum);
  }
}

/// Sledge Value to store numerical counter.
class PosNegCounterValue<T extends num> extends BaseValue<T> {
  final _PosNegCounterValue<T> _counter;
  final DataConverter<int, T> _converter;

  /// Constructor.
  PosNegCounterValue(int id, [Change init])
      : _converter = new DataConverter<int, T>(),
        _counter =
            new _PosNegCounterValue<T>(id, new Converter<T>().defaultValue) {
    applyChanges(init ?? new Change());
  }

  /// Ends transaction and retrieve its data.
  @override
  Change put() => _converter.serialize(_counter.put());

  /// Applies external transactions.
  @override
  void applyChanges(Change input) =>
      _counter.applyChanges(_converter.deserialize(input));

  /// Adds value (possibly negative) to counter.
  void add(final T delta) {
    _counter.add(delta);
    observer.valueWasChanged();
  }

  /// Gets current value of counter.
  T get value => _counter.value;

  /// Gets Stream of changes.
  @override
  Stream<T> get onChange => _counter.onChange;
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../change.dart';
import '../leaf_value.dart';
import '../uint8list_ops.dart';
import '../value_observer.dart';
import 'converted_change.dart';
import 'converter.dart';
import 'key_value_storage.dart';

// TODO: keep one value per connection.
/// Implementation of Positive Negative Counter CRDT.
/// For each instance we create a pair of monotonically increasing variables:
/// one to accumulate increments, and another to accumulate decrements. The
/// total value of the counter is the sum, over all instances, of the difference
/// between the positive and negative variable.
/// Each variable pair may be modified by only one instance, so the
/// Last One Wins merge strategy works.
class _PosNegCounterValue<T extends num> {
  final KeyValueStorage<Uint8List, T> _storage;
  final Uint8List _currentInstanceId;
  T _sum;
  final T _defaultValue;
  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();
  static final _listEquality = new ListEquality();

  _PosNegCounterValue(this._currentInstanceId, this._defaultValue)
      : _storage = new KeyValueStorage<Uint8List, T>(
            equals: _listEquality.equals, hashCode: _listEquality.hash) {
    _sum = _defaultValue;
  }

  Uint8List get _positiveKey =>
      concatUint8Lists(new Uint8List.fromList([0]), _currentInstanceId);
  Uint8List get _negativeKey =>
      concatUint8Lists(new Uint8List.fromList([1]), _currentInstanceId);
  bool _isKeyPositive(Uint8List key) => key[0] == 0;

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

  void _addPositiveValue(Uint8List key, T delta) {
    T cur = _storage[key] ?? _defaultValue;
    _storage[key] = cur + delta;
  }

  ConvertedChange<Uint8List, T> getChange() => _storage.getChange();

  void applyChange(ConvertedChange<Uint8List, T> change) {
    for (var key in change.changedEntries.keys) {
      var diff = change.changedEntries[key] - (_storage[key] ?? _defaultValue);
      if (_isKeyPositive(key)) {
        _sum += diff;
      } else {
        _sum -= diff;
      }
    }
    _storage.applyChange(change);
    _changeController.add(_sum);
  }
}

/// Sledge Value to store numerical counter.
class PosNegCounterValue<T extends num> implements LeafValue {
  final _PosNegCounterValue<T> _counter;
  final DataConverter<Uint8List, T> _converter;
  ValueObserver _observer;

  /// Constructor.
  PosNegCounterValue(Uint8List id, [Change init])
      : _converter = new DataConverter<Uint8List, T>(),
        _counter =
            new _PosNegCounterValue<T>(id, new Converter<T>().defaultValue) {
    applyChange(init ?? new Change());
  }

  @override
  Change getChange() => _converter.serialize(_counter.getChange());

  @override
  void applyChange(Change input) =>
      _counter.applyChange(_converter.deserialize(input));

  @override
  Stream<T> get onChange => _counter.onChange;

  @override
  set observer(ValueObserver observer) {
    _observer = observer;
  }

  /// Adds value (possibly negative) to counter.
  void add(final T delta) {
    _counter.add(delta);
    _observer.valueWasChanged();
  }

  /// Returns current value of counter.
  T get value => _counter.value;
}

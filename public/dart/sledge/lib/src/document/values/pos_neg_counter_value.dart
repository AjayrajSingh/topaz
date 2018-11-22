// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../uint8list_ops.dart';
import '../change.dart';
import '../leaf_value.dart';
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
class PosNegCounterValue<T extends num> implements LeafValue {
  final KeyValueStorage<Uint8List, T> _storage;
  final Uint8List _currentInstanceId;
  T _sum;
  final T _defaultValue;
  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();
  static final _listEquality = new ListEquality();
  final MapToKVListConverter<Uint8List, T> _converter;

  /// Default constructor.
  PosNegCounterValue(this._currentInstanceId)
      : _defaultValue = new Converter<T>().defaultValue,
        _converter = new MapToKVListConverter<Uint8List, T>(),
        _storage = new KeyValueStorage<Uint8List, T>(
            equals: _listEquality.equals, hashCode: _listEquality.hash) {
    _sum = _defaultValue;
  }

  Uint8List get _positiveKey =>
      concatUint8Lists(new Uint8List.fromList([0]), _currentInstanceId);
  Uint8List get _negativeKey =>
      concatUint8Lists(new Uint8List.fromList([1]), _currentInstanceId);
  bool _isKeyPositive(Uint8List key) => key[0] == 0;

  @override
  Stream<T> get onChange => _changeController.stream;

  /// Adds the [delta] to this counter. The [delta] can potentially be negative.
  void add(T delta) {
    if (delta > 0) {
      _addPositiveValue(_positiveKey, delta);
    } else {
      _addPositiveValue(_negativeKey, -delta);
    }
    _sum += delta;
  }

  /// Returns the current value of this counter.
  T get value => _sum;

  void _addPositiveValue(Uint8List key, T delta) {
    T cur = _storage[key] ?? _defaultValue;
    _storage[key] = cur + delta;
  }

  @override
  Change getChange() => _converter.serialize(_storage.getChange());

  @override
  void completeTransaction() {
    _storage.completeTransaction();
  }

  @override
  void applyChange(Change input) {
    final ConvertedChange<Uint8List, T> change = _converter.deserialize(input);
    for (final changedEntry in change.changedEntries.entries) {
      var diff =
          changedEntry.value - (_storage[changedEntry.key] ?? _defaultValue);
      if (_isKeyPositive(changedEntry.key)) {
        _sum += diff;
      } else {
        _sum -= diff;
      }
    }
    _storage.applyChange(change);
    _changeController.add(_sum);
  }

  @override
  void rollbackChange() {
    // Rolls back [_storage] state, and [_sum] value.
    // Only values for "local keys" ([_positiveKey] and [_negatieKey]) might be
    // affected in the current transaction.
    // To roll back and restore the value of [_sum] from before the transaction,
    // undo adding the [_positiveKey] and subtracting [_negativeKey], roll back
    // in [_storage], and then update [_sum] with the reverted values from the
    // "local keys".
    _sum -= _storage[_positiveKey];
    _sum += _storage[_negativeKey];
    _storage.rollbackChange();
    _sum += _storage[_positiveKey];
    _sum -= _storage[_negativeKey];
  }

  @override
  set observer(ValueObserver observer) {
    _storage.observer = observer;
  }
}

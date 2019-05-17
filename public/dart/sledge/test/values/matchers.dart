// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:collection/collection.dart';
import 'package:matcher/matcher.dart';
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:sledge/src/sledge_errors.dart';
import 'package:test/test.dart';

const Equality<List<int>> _listEquality = ListEquality<int>();

class KeyValueEquality implements Equality<KeyValue> {
  // Default constructor;
  const KeyValueEquality();

  @override
  bool equals(KeyValue kv1, KeyValue kv2) {
    return _listEquality.equals(kv1.key, kv2.key) &&
        _listEquality.equals(kv1.value, kv2.value);
  }

  @override
  int hash(KeyValue kv) {
    return 0;
  }

  @override
  bool isValidKey(Object key) {
    return key is KeyValue;
  }
}

const _keyValueEquality = KeyValueEquality();
const ListEquality _keyValueListEquality =
    ListEquality<KeyValue>(_keyValueEquality);
const ListEquality _keysListEquality =
    ListEquality<List<int>>(_listEquality);

class KeyValueMatcher extends Matcher {
  final KeyValue _kv;

  // Default constructor.
  KeyValueMatcher(this._kv);

  @override
  bool matches(dynamic kv, Map matchState) {
    return _listEquality.equals(kv.key, _kv.key) &&
        _listEquality.equals(kv.value, _kv.value);
  }

  @override
  Description describe(Description description) =>
      description.add('KeyValue equals to '); // TODO add description
}

class ChangeMatcher extends Matcher {
  final Change _change;

  // Default constructor.
  ChangeMatcher(this._change);

  @override
  bool matches(dynamic change, Map matchState) {
    return _keyValueListEquality.equals(
            change.changedEntries, _change.changedEntries) &&
        _keysListEquality.equals(change.deletedKeys, _change.deletedKeys);
  }

  @override
  Description describe(Description description) =>
      description.add('Change matcher.'); // TODO add description.
}

class OrderedListChangeMatcher extends Matcher {
  final OrderedListChange _change;

  // Default constructor.
  OrderedListChangeMatcher(this._change);

  @override
  bool matches(dynamic change, Map matchState) {
    return _listEquality.equals(change.insertedElements.keys.toList(),
            _change.insertedElements.keys.toList()) &&
        _listEquality.equals(change.insertedElements.values.toList(),
            _change.insertedElements.values.toList()) &&
        _listEquality.equals(change.deletedPositions, _change.deletedPositions);
  }

  @override
  Description describe(Description description) =>
      description.add('OrderedListChange matcher'); // TODO add description.
}

/// Matcher for InternalSledgeErrors.
final Matcher throwsInternalError =
    throwsA(TypeMatcher<InternalSledgeError>());

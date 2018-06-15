// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:matcher/matcher.dart';
import 'package:sledge/src/document/values/key_value.dart';

class Uint8ListMatcher extends Matcher {
  final Uint8List _list;
  final ListEquality listEquality = new ListEquality();

  Uint8ListMatcher(this._list);

  bool matches(Uint8List list, Map matchState) {
    return listEquality.equals(list, _list);
  }

  Description describe(Description description) =>
      description.add('Uint8List equals to ').addDescriptionOf(_list.toList());
}

class KeyValueMatcher extends Matcher {
  final KeyValue _kv;
  final ListEquality listEquality = new ListEquality();

  KeyValueMatcher(this._kv);

  bool matches(KeyValue kv, Map matchState) {
    return listEquality.equals(kv.key, _kv.key) &&
        listEquality.equals(kv.value, _kv.value);
  }

  Description describe(Description description) =>
      description.add('KeyValue equals to ').addDescriptionOf(_kv.toList());
}

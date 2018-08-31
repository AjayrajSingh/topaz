// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'hash_codes.dart';

abstract class Struct {
  const Struct();

  List<Object> get $fields;

  @override
  int get hashCode => deepHash($fields);

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    final Struct otherStruct = other;
    return deepEquals($fields, otherStruct.$fields);
  }
}

typedef StructFactory<T> = T Function(List<Object> argv);

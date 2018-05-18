// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

abstract class Struct {
  const Struct();

  List<Object> get $fields;
}

typedef StructFactory<T> = T Function(List<Object> argv);

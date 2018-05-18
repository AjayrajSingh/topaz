// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

abstract class Union {
  const Union();

  int get $index;
  Object get $data;
}

typedef UnionFactory<T> = T Function(int index, Object data);

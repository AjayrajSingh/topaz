// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:fidl.internal' as fidl;

Timer timer;

void main(List args) {
  print('Hello, Dart!');

  timer = new Timer(const Duration(seconds: 1), () {
    print('Goodbye, Dart!');
    fidl.exit(42);
  });
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:fuchsia' as fuchsia;

Timer timer;

void main(List args) {
  print('Hello, Dart!');

  timer = new Timer(const Duration(seconds: 1), () {
    print('Goodbye, Dart!');
    fuchsia.exit(42);
  });
}

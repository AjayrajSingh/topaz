// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia/fuchsia.dart';

import './benchmark.dart';
import './string.dart';

void main(List<String> args) {
  // Include string benchmarks.
  addStringBenchmarks();

  // Run all benchmarks.
  runBenchmarks();

  // Ciao!
  exit(0);
}

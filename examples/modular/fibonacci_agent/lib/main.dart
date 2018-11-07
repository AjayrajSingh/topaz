// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_fibonacci/fidl_async.dart';

import 'package:fuchsia_modular/agent.dart';
import 'src/fibonacci_service_impl.dart';

void main(List<String> args) {
  Agent().exposeService(FibonacciServiceImpl(), FibonacciServiceData());
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';

import 'package:fuchsia_modular/agent.dart';
import 'src/fibonacci_service_impl.dart';

void main(List<String> args) {
  setupLogger(name: 'fibonacci-agent');
    Agent().exposeService(FibonacciServiceImpl());
}

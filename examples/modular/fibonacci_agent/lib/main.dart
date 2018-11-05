// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_fibonacci/fidl_async.dart' as fidl_fib;

import 'package:fuchsia_modular/agent.dart';
import 'src/fibonacci_service_impl.dart';

void main(List<String> args) {
  final FibonacciServiceImpl fibonacciServiceImpl = FibonacciServiceImpl();
  final _bindings = Agent().getIncomingBindings();
  
  // TODO(nkorsote): replace the following temporary way to add a service
  Agent().addService(
    (InterfaceRequest<fidl_fib.FibonacciService> request) => _bindings.add(
        fidl_fib.FibonacciServiceBinding()
          ..bind(fibonacciServiceImpl, request)),
    fidl_fib.FibonacciService.$serviceName,
  );
}

// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_fibonacci/fidl_async.dart';

import 'package:fuchsia_modular/agent.dart';
import 'src/fibonacci_service_impl.dart';

void main(List<String> args) {
  // Note [exposeServiceProvider] was used instead of [exposeService] for no
  // particular reason other than to illustrate how a provider function can be
  // used. In this specific use case [exposeService] would work just fine. 
  Agent().exposeServiceProvider(getService, FibonacciServiceData());
}

/// Service provider function which will be called during service connection
/// request to get the service that is needed to be exposed.
FutureOr<FibonacciServiceImpl> getService() {
  return Future(() {
    //create new Future and await on it before exposing service
    return Future.delayed(
      Duration(milliseconds: 1),
      () => FibonacciServiceImpl(),
    );
  });
}



// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_examples_hello/fidl.dart';

class _HelloImpl extends Hello {
  final HelloBinding _binding = new HelloBinding();

  void bind(InterfaceRequest<Hello> request) {
    _binding.bind(this, request);
  }

  @override
  void say(String request, void callback(String response)) {
    callback((request == 'hello') ? 'hola from Dart!' : 'adios from Dart!');
  }
}

void main(List<String> args) {
  ApplicationContext context = new ApplicationContext.fromStartupInfo();

  context.outgoingServices
      .addServiceForName(new _HelloImpl().bind, Hello.$serviceName);
}

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.fidl.dart/core.dart' as core;

import 'package:apps.modular.lib.app.dart/app.dart';
import 'package:apps.modular.examples.hello_app/hello.fidl.dart';

class HelloImpl extends Hello {
  @override
  void Say(String request, void callback(String response)) {
    callback((request == "hello") ? "hola from Dart!" : "adios from Dart!");
  }
}

void main(List<String> args) {
  ApplicationContext context = new ApplicationContext.fromStartupInfo();

  context.outgoingServices.addServiceForName((core.Channel channel) {
    new HelloStub.fromChannel(channel, new HelloImpl());
  }, Hello.serviceName);
}

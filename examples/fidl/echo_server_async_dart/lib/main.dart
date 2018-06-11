// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fidl_examples_echo/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';

class _EchoImpl extends Echo {
  final EchoBinding _binding = new EchoBinding();

  void bind(InterfaceRequest<Echo> request) {
    _binding.bind(this, request);
  }

  @override
  Future<String> echoString(String value) async {
    print('EchoString: $value');
    return value;
  }
}

StartupContext _context;
_EchoImpl _echo;

void main(List<String> args) {
  _context = new StartupContext.fromStartupInfo();
  _echo = new _EchoImpl();
  _context.outgoingServices
      .addServiceForName<Echo>(_echo.bind, Echo.$serviceName);
}
